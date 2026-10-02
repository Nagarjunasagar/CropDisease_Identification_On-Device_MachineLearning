import 'dart:convert';

/// Human-readable guidance for each class, loaded from
/// `assets/models/disease_info.json` (shared with the Qt edge app).
class DiseaseInfo {
  const DiseaseInfo({
    required this.id,
    required this.name,
    required this.cause,
    required this.type,
    required this.symptoms,
    required this.management,
  });

  final String id;
  final String name;
  final String cause;
  final String type;
  final List<String> symptoms;
  final List<String> management;

  bool get isHealthy => id == 'healthy';

  factory DiseaseInfo.fromJson(String id, Map<String, Object?> json) =>
      DiseaseInfo(
        id: id,
        name: json['name']! as String,
        cause: json['cause']! as String,
        type: json['type']! as String,
        symptoms: (json['symptoms']! as List<Object?>).cast<String>(),
        management: (json['management']! as List<Object?>).cast<String>(),
      );
}

class DiseaseCatalog {
  DiseaseCatalog(this._byId, this.disclaimer);

  final Map<String, DiseaseInfo> _byId;
  final String disclaimer;

  factory DiseaseCatalog.parse(String jsonText) {
    final root = jsonDecode(jsonText) as Map<String, Object?>;
    final classes = root['classes']! as Map<String, Object?>;
    return DiseaseCatalog(
      {
        for (final e in classes.entries)
          e.key: DiseaseInfo.fromJson(e.key, e.value! as Map<String, Object?>),
      },
      root['disclaimer']! as String,
    );
  }

  Iterable<String> get ids => _byId.keys;

  /// Falls back to a generic entry so a label/catalog mismatch never crashes.
  DiseaseInfo operator [](String id) =>
      _byId[id] ??
      DiseaseInfo(
        id: id,
        name: id.replaceAll('_', ' '),
        cause: 'Unknown',
        type: 'Unknown',
        symptoms: const [],
        management: const [],
      );
}
