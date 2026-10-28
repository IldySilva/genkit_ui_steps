// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'step5_local.dart';

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

base class NavigateInput {
  /// Creates a [NavigateInput] from a JSON map.
  factory NavigateInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  NavigateInput._(this._json);

  NavigateInput({required String screen}) {
    _json = {'screen': screen};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [NavigateInput].
  static const SchemanticType<NavigateInput> $schema =
      _NavigateInputTypeFactory();

  String get screen {
    return _json['screen'] as String;
  }

  set screen(String value) {
    _json['screen'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [NavigateInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _NavigateInputTypeFactory extends SchemanticType<NavigateInput> {
  const _NavigateInputTypeFactory();

  @override
  NavigateInput parse(Object? json) {
    return NavigateInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'NavigateInput',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'screen': <String, Object?>{'type': 'string'},
      },
      'required': ['screen'],
    },
    dependencies: [],
  );
}
