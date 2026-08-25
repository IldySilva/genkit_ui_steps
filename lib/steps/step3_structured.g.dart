// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'step3_structured.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class ThemeCommand {
  /// Creates a [ThemeCommand] from a JSON map.
  factory ThemeCommand.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ThemeCommand._(this._json);

  ThemeCommand({required String color, required String mood}) {
    _json = {'color': color, 'mood': mood};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ThemeCommand].
  static const SchemanticType<ThemeCommand> $schema =
      _ThemeCommandTypeFactory();

  String get color {
    return _json['color'] as String;
  }

  set color(String value) {
    _json['color'] = value;
  }

  String get mood {
    return _json['mood'] as String;
  }

  set mood(String value) {
    _json['mood'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ThemeCommand] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ThemeCommandTypeFactory extends SchemanticType<ThemeCommand> {
  const _ThemeCommandTypeFactory();

  @override
  ThemeCommand parse(Object? json) {
    return ThemeCommand._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ThemeCommand',
    definition: $Schema
        .object(
          properties: {'color': $Schema.string(), 'mood': $Schema.string()},
          required: ['color', 'mood'],
        )
        .value,
    dependencies: [],
  );
}
