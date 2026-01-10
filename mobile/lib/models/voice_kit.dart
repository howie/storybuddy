enum Gender { male, female, neutral }

enum AgeGroup { child, adult, senior }

enum VoiceStyle { narrator, character, both }

class VoiceKit {

  VoiceKit({
    required this.id,
    required this.name,
    required this.provider, required this.version, this.description,
    this.downloadSize = 0,
    this.isBuiltin = true,
    this.isDownloaded = false,
    this.voices = const [],
  });

  factory VoiceKit.fromJson(Map<String, dynamic> json) {
    return VoiceKit(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      provider: json['provider'] as String,
      version: json['version'] as String,
      downloadSize: json['download_size'] as int? ?? 0,
      isBuiltin: json['is_builtin'] as bool? ?? true,
      isDownloaded: json['is_downloaded'] as bool? ?? false,
      voices: (json['voices'] as List<dynamic>?)
              ?.map((e) => VoiceCharacter.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
  final String id;
  final String name;
  final String? description;
  final String provider;
  final String version;
  final int downloadSize;
  final bool isBuiltin;
  final bool isDownloaded;
  final List<VoiceCharacter> voices;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'provider': provider,
      'version': version,
      'download_size': downloadSize,
      'is_builtin': isBuiltin,
      'is_downloaded': isDownloaded,
      'voices': voices.map((e) => e.toJson()).toList(),
    };
  }
}

class VoiceCharacter {

  VoiceCharacter({
    required this.id,
    required this.kitId,
    required this.name,
    required this.providerVoiceId,
    required this.gender, required this.ageGroup, required this.style, this.ssmlOptions,
    this.previewUrl,
    this.previewText,
  });

  factory VoiceCharacter.fromJson(Map<String, dynamic> json) {
    return VoiceCharacter(
      id: json['id'] as String,
      kitId: json['kit_id'] as String,
      name: json['name'] as String,
      providerVoiceId: json['provider_voice_id'] as String,
      ssmlOptions: json['ssml_options'] as Map<String, dynamic>?,
      gender: Gender.values.firstWhere(
        (e) => e.toString().split('.').last == json['gender'],
        orElse: () => Gender.neutral,
      ),
      ageGroup: AgeGroup.values.firstWhere(
        (e) => e.toString().split('.').last == json['age_group'],
        orElse: () => AgeGroup.adult,
      ),
      style: VoiceStyle.values.firstWhere(
        (e) => e.toString().split('.').last == json['style'],
        orElse: () => VoiceStyle.both,
      ),
      previewUrl: json['preview_url'] as String?,
      previewText: json['preview_text'] as String?,
    );
  }
  final String id;
  final String kitId;
  final String name;
  final String providerVoiceId;
  final Map<String, dynamic>? ssmlOptions;
  final Gender gender;
  final AgeGroup ageGroup;
  final VoiceStyle style;
  final String? previewUrl;
  final String? previewText;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kit_id': kitId,
      'name': name,
      'provider_voice_id': providerVoiceId,
      'ssml_options': ssmlOptions,
      'gender': gender.toString().split('.').last,
      'age_group': ageGroup.toString().split('.').last,
      'style': style.toString().split('.').last,
      'preview_url': previewUrl,
      'preview_text': previewText,
    };
  }
}
