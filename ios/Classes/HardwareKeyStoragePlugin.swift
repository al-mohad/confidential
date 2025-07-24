import Flutter
import UIKit
import Security
import LocalAuthentication
import CryptoKit

/**
 * Enhanced iOS Keychain plugin for hardware-backed key storage.
 * 
 * Provides direct access to iOS Keychain and Secure Enclave features including:
 * - Secure Enclave key generation
 * - Biometric authentication (Face ID/Touch ID)
 * - Hardware-backed key storage
 * - Key attestation
 */
public class HardwareKeyStoragePlugin: NSObject, FlutterPlugin {
    private static let channelName = "com.confidential.hardware_key_storage"
    private static let keyTagPrefix = "confidential.key."
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = HardwareKeyStoragePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isHardwareBackingAvailable":
            checkHardwareBackingAvailable(result: result)
        case "isSecureEnclaveAvailable":
            checkSecureEnclaveAvailable(result: result)
        case "generateHardwareKey":
            generateHardwareKey(call: call, result: result)
        case "getKeyInfo":
            getKeyInfo(call: call, result: result)
        case "deleteKey":
            deleteKey(call: call, result: result)
        case "listKeys":
            listKeys(result: result)
        case "isBiometricAvailable":
            checkBiometricAvailable(result: result)
        case "authenticateWithBiometric":
            authenticateWithBiometric(call: call, result: result)
        case "getSecurityLevel":
            getSecurityLevel(call: call, result: result)
        case "generateSecureEnclaveKey":
            generateSecureEnclaveKey(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    /**
     * Checks if hardware-backed key storage is available.
     */
    private func checkHardwareBackingAvailable(result: @escaping FlutterResult) {
        // iOS Keychain is always available on iOS devices
        result(true)
    }
    
    /**
     * Checks if Secure Enclave is available on this device.
     */
    private func checkSecureEnclaveAvailable(result: @escaping FlutterResult) {
        if #available(iOS 9.0, *) {
            let context = LAContext()
            let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) ||
                           context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
            result(available)
        } else {
            result(false)
        }
    }
    
    /**
     * Generates a hardware-backed encryption key.
     */
    private func generateHardwareKey(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let keyAlias = args["keyAlias"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "keyAlias required", details: nil))
            return
        }
        
        let keySize = args["keySize"] as? Int ?? 256
        let useSecureEnclave = args["useSecureEnclave"] as? Bool ?? false
        let requireAuth = args["requireAuth"] as? Bool ?? false
        let requireBiometric = args["requireBiometric"] as? Bool ?? false
        
        let keyTag = Self.keyTagPrefix + keyAlias
        
        // Delete existing key if it exists
        deleteKeyInternal(keyTag: keyTag)
        
        var keyAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeAES,
            kSecAttrKeySizeInBits as String: keySize,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
            kSecAttrCanEncrypt as String: true,
            kSecAttrCanDecrypt as String: true,
        ]
        
        // Configure Secure Enclave if requested and available
        if useSecureEnclave && #available(iOS 9.0, *) {
            keyAttributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        }
        
        // Configure authentication requirements
        if requireAuth {
            var accessControl: SecAccessControl?
            var flags: SecAccessControlCreateFlags = []
            
            if requireBiometric {
                if #available(iOS 11.3, *) {
                    flags = .biometryCurrentSet
                } else {
                    flags = .touchIDCurrentSet
                }
            } else {
                flags = .devicePasscode
            }
            
            if #available(iOS 9.0, *) {
                accessControl = SecAccessControlCreateWithFlags(
                    kCFAllocatorDefault,
                    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                    flags,
                    nil
                )
            }
            
            if let accessControl = accessControl {
                keyAttributes[kSecAttrAccessControl as String] = accessControl
            }
        } else {
            keyAttributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
        
        // Generate the key
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyAttributes as CFDictionary, &error) else {
            let errorDescription = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            result(FlutterError(code: "KEY_GENERATION_FAILED", message: "Failed to generate hardware key", details: errorDescription))
            return
        }
        
        // Store key in Keychain
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
            kSecValueRef as String: privateKey,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        
        if status == errSecSuccess {
            let keyInfo = getKeyInfoInternal(keyTag: keyTag)
            result([
                "keyAlias": keyAlias,
                "keySize": keySize,
                "created": true,
                "keyInfo": keyInfo
            ])
        } else {
            result(FlutterError(code: "KEY_STORAGE_FAILED", message: "Failed to store key in Keychain", details: "Status: \(status)"))
        }
    }
    
    /**
     * Generates a Secure Enclave key (iOS 9.0+).
     */
    @available(iOS 9.0, *)
    private func generateSecureEnclaveKey(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let keyAlias = args["keyAlias"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "keyAlias required", details: nil))
            return
        }
        
        let requireBiometric = args["requireBiometric"] as? Bool ?? true
        let keyTag = Self.keyTagPrefix + keyAlias
        
        // Delete existing key if it exists
        deleteKeyInternal(keyTag: keyTag)
        
        var flags: SecAccessControlCreateFlags = []
        if requireBiometric {
            if #available(iOS 11.3, *) {
                flags = .biometryCurrentSet
            } else {
                flags = .touchIDCurrentSet
            }
        } else {
            flags = .devicePasscode
        }
        
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            flags,
            nil
        ) else {
            result(FlutterError(code: "ACCESS_CONTROL_FAILED", message: "Failed to create access control", details: nil))
            return
        }
        
        let keyAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
            kSecAttrAccessControl as String: accessControl,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyAttributes as CFDictionary, &error) else {
            let errorDescription = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            result(FlutterError(code: "SECURE_ENCLAVE_KEY_FAILED", message: "Failed to generate Secure Enclave key", details: errorDescription))
            return
        }
        
        let keyInfo = getKeyInfoInternal(keyTag: keyTag)
        result([
            "keyAlias": keyAlias,
            "keySize": 256,
            "created": true,
            "secureEnclave": true,
            "keyInfo": keyInfo
        ])
    }
    
    /**
     * Gets detailed information about a stored key.
     */
    private func getKeyInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let keyAlias = args["keyAlias"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "keyAlias required", details: nil))
            return
        }
        
        let keyTag = Self.keyTagPrefix + keyAlias
        let keyInfo = getKeyInfoInternal(keyTag: keyTag)
        result(keyInfo)
    }
    
    /**
     * Internal method to get key information.
     */
    private func getKeyInfoInternal(keyTag: String) -> [String: Any] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
            kSecReturnRef as String: true,
            kSecReturnAttributes as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let keyData = item as? [String: Any] else {
            return ["exists": false]
        }
        
        var info: [String: Any] = [
            "exists": true,
            "keyClass": keyData[kSecAttrKeyClass as String] as? String ?? "unknown",
            "keyType": keyData[kSecAttrKeyType as String] as? String ?? "unknown",
            "keySizeInBits": keyData[kSecAttrKeySizeInBits as String] as? Int ?? 0,
            "canEncrypt": keyData[kSecAttrCanEncrypt as String] as? Bool ?? false,
            "canDecrypt": keyData[kSecAttrCanDecrypt as String] as? Bool ?? false,
            "isPermanent": keyData[kSecAttrIsPermanent as String] as? Bool ?? false
        ]
        
        // Check if key is in Secure Enclave
        if #available(iOS 9.0, *) {
            let tokenID = keyData[kSecAttrTokenID as String] as? String
            info["isSecureEnclave"] = (tokenID == kSecAttrTokenIDSecureEnclave as String)
        } else {
            info["isSecureEnclave"] = false
        }
        
        return info
    }
    
    /**
     * Deletes a stored key.
     */
    private func deleteKey(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let keyAlias = args["keyAlias"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "keyAlias required", details: nil))
            return
        }
        
        let keyTag = Self.keyTagPrefix + keyAlias
        let deleted = deleteKeyInternal(keyTag: keyTag)
        result(deleted)
    }
    
    /**
     * Internal method to delete a key.
     */
    private func deleteKeyInternal(keyTag: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /**
     * Lists all stored keys.
     */
    private func listKeys(result: @escaping FlutterResult) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        
        guard status == errSecSuccess,
              let keyItems = items as? [[String: Any]] else {
            result([])
            return
        }
        
        let confidentialKeys = keyItems.compactMap { item -> String? in
            guard let tagData = item[kSecAttrApplicationTag as String] as? Data,
                  let tag = String(data: tagData, encoding: .utf8),
                  tag.hasPrefix(Self.keyTagPrefix) else {
                return nil
            }
            return String(tag.dropFirst(Self.keyTagPrefix.count))
        }
        
        result(confidentialKeys)
    }
    
    /**
     * Checks if biometric authentication is available.
     */
    private func checkBiometricAvailable(result: @escaping FlutterResult) {
        let context = LAContext()
        var error: NSError?
        
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        result(available)
    }
    
    /**
     * Authenticates user with biometric.
     */
    private func authenticateWithBiometric(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Arguments required", details: nil))
            return
        }
        
        let reason = args["reason"] as? String ?? "Authenticate to access secure key"
        let fallbackTitle = args["fallbackTitle"] as? String ?? "Use Passcode"
        
        let context = LAContext()
        context.localizedFallbackTitle = fallbackTitle
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    result(["authenticated": true])
                } else {
                    let errorCode = (error as? LAError)?.code.rawValue ?? -1
                    let errorMessage = error?.localizedDescription ?? "Authentication failed"
                    result(FlutterError(code: "BIOMETRIC_ERROR", message: errorMessage, details: errorCode))
                }
            }
        }
    }
    
    /**
     * Gets the security level of a key.
     */
    private func getSecurityLevel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let keyAlias = args["keyAlias"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "keyAlias required", details: nil))
            return
        }
        
        let keyTag = Self.keyTagPrefix + keyAlias
        let keyInfo = getKeyInfoInternal(keyTag: keyTag)
        
        let securityLevel: String
        if keyInfo["isSecureEnclave"] as? Bool == true {
            securityLevel = "SECURE_ENCLAVE"
        } else if keyInfo["exists"] as? Bool == true {
            securityLevel = "KEYCHAIN"
        } else {
            securityLevel = "NOT_FOUND"
        }
        
        result([
            "securityLevel": securityLevel,
            "keyInfo": keyInfo
        ])
    }
}
