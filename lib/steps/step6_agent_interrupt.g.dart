// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'step6_agent_interrupt.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class ChangeThemeInput {
  /// Creates a [ChangeThemeInput] from a JSON map.
  factory ChangeThemeInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ChangeThemeInput._(this._json);

  ChangeThemeInput({required String color}) {
    _json = {'color': color};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ChangeThemeInput].
  static const SchemanticType<ChangeThemeInput> $schema =
      _ChangeThemeInputTypeFactory();

  String get color {
    return _json['color'] as String;
  }

  set color(String value) {
    _json['color'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ChangeThemeInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ChangeThemeInputTypeFactory
    extends SchemanticType<ChangeThemeInput> {
  const _ChangeThemeInputTypeFactory();

  @override
  ChangeThemeInput parse(Object? json) {
    return ChangeThemeInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ChangeThemeInput',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'color': <String, Object?>{'type': 'string'},
      },
      'required': ['color'],
    },
    dependencies: [],
  );
}

base class ResetSettingsInput {
  /// Creates a [ResetSettingsInput] from a JSON map.
  factory ResetSettingsInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ResetSettingsInput._(this._json);

  ResetSettingsInput({required String reason}) {
    _json = {'reason': reason};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ResetSettingsInput].
  static const SchemanticType<ResetSettingsInput> $schema =
      _ResetSettingsInputTypeFactory();

  String get reason {
    return _json['reason'] as String;
  }

  set reason(String value) {
    _json['reason'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ResetSettingsInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ResetSettingsInputTypeFactory
    extends SchemanticType<ResetSettingsInput> {
  const _ResetSettingsInputTypeFactory();

  @override
  ResetSettingsInput parse(Object? json) {
    return ResetSettingsInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ResetSettingsInput',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'reason': <String, Object?>{'type': 'string'},
      },
      'required': ['reason'],
    },
    dependencies: [],
  );
}
