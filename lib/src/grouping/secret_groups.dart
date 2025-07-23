/// Enhanced secret grouping and namespace management.
library;

import '../configuration/configuration.dart';

/// Enhanced secret definition with grouping support.
class GroupedSecretDefinition extends SecretDefinition {
  /// The group this secret belongs to.
  final String? group;

  /// Tags for categorizing secrets.
  final List<String> tags;

  /// Description of the secret.
  final String? description;

  /// Whether this secret is deprecated.
  final bool deprecated;

  /// Environment where this secret is applicable.
  final String? environment;

  /// Priority level for loading order.
  final int priority;

  const GroupedSecretDefinition({
    required super.name,
    required super.value,
    super.accessModifier,
    super.namespace,
    this.group,
    this.tags = const [],
    this.description,
    this.deprecated = false,
    this.environment,
    this.priority = 0,
  });

  /// Creates a GroupedSecretDefinition from YAML data.
  static GroupedSecretDefinition fromYaml(dynamic yaml) {
    final base = SecretDefinition.fromYaml(yaml);
    
    if (yaml is! Map) {
      return GroupedSecretDefinition(
        name: base.name,
        value: base.value,
        accessModifier: base.accessModifier,
        namespace: base.namespace,
      );
    }

    return GroupedSecretDefinition(
      name: base.name,
      value: base.value,
      accessModifier: base.accessModifier,
      namespace: base.namespace,
      group: yaml['group'] as String?,
      tags: (yaml['tags'] as List?)?.cast<String>() ?? [],
      description: yaml['description'] as String?,
      deprecated: yaml['deprecated'] as bool? ?? false,
      environment: yaml['environment'] as String?,
      priority: yaml['priority'] as int? ?? 0,
    );
  }

  /// Checks if this secret matches the given filter.
  bool matchesFilter(SecretFilter filter) {
    if (filter.groups.isNotEmpty && !filter.groups.contains(group)) {
      return false;
    }

    if (filter.tags.isNotEmpty && !filter.tags.any((tag) => tags.contains(tag))) {
      return false;
    }

    if (filter.environment != null && environment != filter.environment) {
      return false;
    }

    if (filter.excludeDeprecated && deprecated) {
      return false;
    }

    if (filter.namePattern != null && !RegExp(filter.namePattern!).hasMatch(name)) {
      return false;
    }

    return true;
  }

  @override
  String toString() {
    final parts = <String>[
      'name: $name',
      if (group != null) 'group: $group',
      if (tags.isNotEmpty) 'tags: ${tags.join(', ')}',
      if (environment != null) 'environment: $environment',
      if (deprecated) 'deprecated: true',
    ];
    return 'GroupedSecretDefinition(${parts.join(', ')})';
  }
}

/// Filter for selecting secrets based on criteria.
class SecretFilter {
  /// Groups to include.
  final List<String> groups;

  /// Tags to include (any match).
  final List<String> tags;

  /// Environment to filter by.
  final String? environment;

  /// Whether to exclude deprecated secrets.
  final bool excludeDeprecated;

  /// Regular expression pattern for name matching.
  final String? namePattern;

  /// Minimum priority level.
  final int? minPriority;

  const SecretFilter({
    this.groups = const [],
    this.tags = const [],
    this.environment,
    this.excludeDeprecated = false,
    this.namePattern,
    this.minPriority,
  });

  /// Creates a filter for a specific group.
  factory SecretFilter.group(String group) {
    return SecretFilter(groups: [group]);
  }

  /// Creates a filter for specific tags.
  factory SecretFilter.tags(List<String> tags) {
    return SecretFilter(tags: tags);
  }

  /// Creates a filter for a specific environment.
  factory SecretFilter.environment(String environment) {
    return SecretFilter(environment: environment);
  }

  /// Creates a filter that excludes deprecated secrets.
  factory SecretFilter.excludeDeprecated() {
    return const SecretFilter(excludeDeprecated: true);
  }
}

/// Enhanced namespace definition with grouping support.
class GroupedNamespaceDefinition extends NamespaceDefinition {
  /// The group this namespace belongs to.
  final String? group;

  /// Description of the namespace.
  final String? description;

  /// Whether this namespace is internal.
  final bool internal;

  /// Dependencies on other namespaces.
  final List<String> dependencies;

  const GroupedNamespaceDefinition({
    required super.isExtension,
    required super.name,
    super.module,
    this.group,
    this.description,
    this.internal = false,
    this.dependencies = const [],
  });

  /// Parses a grouped namespace definition string.
  static GroupedNamespaceDefinition parse(String definition, {Map<String, dynamic>? metadata}) {
    final base = NamespaceDefinition.parse(definition);
    
    return GroupedNamespaceDefinition(
      isExtension: base.isExtension,
      name: base.name,
      module: base.module,
      group: metadata?['group'] as String?,
      description: metadata?['description'] as String?,
      internal: metadata?['internal'] as bool? ?? false,
      dependencies: (metadata?['dependencies'] as List?)?.cast<String>() ?? [],
    );
  }
}

/// Secret group definition for organizing related secrets.
class SecretGroup {
  /// The name of the group.
  final String name;

  /// Description of the group.
  final String? description;

  /// The namespace for this group.
  final String? namespace;

  /// Access modifier for the group.
  final String? accessModifier;

  /// Tags for the group.
  final List<String> tags;

  /// Whether this group is deprecated.
  final bool deprecated;

  /// Environment where this group is applicable.
  final String? environment;

  /// Secrets in this group.
  final List<GroupedSecretDefinition> secrets;

  const SecretGroup({
    required this.name,
    this.description,
    this.namespace,
    this.accessModifier,
    this.tags = const [],
    this.deprecated = false,
    this.environment,
    this.secrets = const [],
  });

  /// Creates a SecretGroup from YAML data.
  static SecretGroup fromYaml(dynamic yaml) {
    if (yaml is! Map) {
      throw ConfigurationException('Secret group definition must be a map');
    }

    final name = yaml['name'] as String?;
    if (name == null || name.isEmpty) {
      throw ConfigurationException('Secret group name is required');
    }

    final secretsYaml = yaml['secrets'] as List?;
    final secrets = secretsYaml
        ?.map((s) => GroupedSecretDefinition.fromYaml(s))
        .toList() ?? <GroupedSecretDefinition>[];

    return SecretGroup(
      name: name,
      description: yaml['description'] as String?,
      namespace: yaml['namespace'] as String?,
      accessModifier: yaml['accessModifier'] as String?,
      tags: (yaml['tags'] as List?)?.cast<String>() ?? [],
      deprecated: yaml['deprecated'] as bool? ?? false,
      environment: yaml['environment'] as String?,
      secrets: secrets,
    );
  }

  /// Filters secrets in this group based on criteria.
  List<GroupedSecretDefinition> filterSecrets(SecretFilter filter) {
    return secrets.where((secret) => secret.matchesFilter(filter)).toList();
  }

  /// Gets secrets sorted by priority.
  List<GroupedSecretDefinition> get secretsByPriority {
    final sorted = List<GroupedSecretDefinition>.from(secrets);
    sorted.sort((a, b) => b.priority.compareTo(a.priority));
    return sorted;
  }

  /// Checks if this group has any secrets with the given tag.
  bool hasTag(String tag) {
    return tags.contains(tag) || secrets.any((secret) => secret.tags.contains(tag));
  }

  @override
  String toString() {
    return 'SecretGroup(name: $name, secrets: ${secrets.length})';
  }
}

/// Manager for organizing secrets into groups and namespaces.
class SecretGroupManager {
  final List<SecretGroup> groups;
  final Map<String, GroupedNamespaceDefinition> namespaces;

  SecretGroupManager({
    this.groups = const [],
    this.namespaces = const {},
  });

  /// Gets all secrets from all groups.
  List<GroupedSecretDefinition> get allSecrets {
    return groups.expand((group) => group.secrets).toList();
  }

  /// Gets secrets filtered by criteria.
  List<GroupedSecretDefinition> getSecrets(SecretFilter filter) {
    return allSecrets.where((secret) => secret.matchesFilter(filter)).toList();
  }

  /// Gets secrets by group name.
  List<GroupedSecretDefinition> getSecretsByGroup(String groupName) {
    final group = groups.firstWhere(
      (g) => g.name == groupName,
      orElse: () => throw ArgumentError('Group "$groupName" not found'),
    );
    return group.secrets;
  }

  /// Gets secrets by tag.
  List<GroupedSecretDefinition> getSecretsByTag(String tag) {
    return allSecrets.where((secret) => secret.tags.contains(tag)).toList();
  }

  /// Gets secrets by environment.
  List<GroupedSecretDefinition> getSecretsByEnvironment(String environment) {
    return allSecrets.where((secret) => secret.environment == environment).toList();
  }

  /// Gets all group names.
  List<String> get groupNames => groups.map((g) => g.name).toList();

  /// Gets all tags used across all secrets.
  Set<String> get allTags {
    final tags = <String>{};
    for (final group in groups) {
      tags.addAll(group.tags);
      for (final secret in group.secrets) {
        tags.addAll(secret.tags);
      }
    }
    return tags;
  }

  /// Gets all environments used across all secrets.
  Set<String> get allEnvironments {
    final environments = <String>{};
    for (final group in groups) {
      if (group.environment != null) {
        environments.add(group.environment!);
      }
      for (final secret in group.secrets) {
        if (secret.environment != null) {
          environments.add(secret.environment!);
        }
      }
    }
    return environments;
  }

  /// Groups secrets by their namespace.
  Map<String, List<GroupedSecretDefinition>> groupByNamespace(String defaultNamespace) {
    final grouped = <String, List<GroupedSecretDefinition>>{};
    
    for (final secret in allSecrets) {
      final namespace = secret.getNamespace(defaultNamespace);
      grouped.putIfAbsent(namespace, () => []).add(secret);
    }
    
    return grouped;
  }

  /// Creates a manager from YAML configuration.
  static SecretGroupManager fromYaml(Map<String, dynamic> yaml) {
    final groupsYaml = yaml['groups'] as List?;
    final groups = groupsYaml
        ?.map((g) => SecretGroup.fromYaml(g))
        .toList() ?? <SecretGroup>[];

    final namespacesYaml = yaml['namespaces'] as Map?;
    final namespaces = <String, GroupedNamespaceDefinition>{};
    
    if (namespacesYaml != null) {
      for (final entry in namespacesYaml.entries) {
        final name = entry.key as String;
        final definition = entry.value as String;
        final metadata = yaml['namespaceMetadata']?[name] as Map<String, dynamic>?;
        
        namespaces[name] = GroupedNamespaceDefinition.parse(definition, metadata: metadata);
      }
    }

    return SecretGroupManager(
      groups: groups,
      namespaces: namespaces,
    );
  }
}
