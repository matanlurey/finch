/// A minimal JSON reader with quasi-sound types and a consistent API.
///
/// The principle of this library is that given a `JsonX` type, that object is
/// confidently known to be that type, with some allowances for APIs that use
/// unchecked casts.
///
/// ## Example
///
/// ```dart
/// import 'package:sound_json/sound_json.dart';
///
/// void main() {
///   final json = JsonObject.parse('{"key": "value"}');
///   final value = json.string('key');
///   print(value); // "value"
/// }
/// ```
library sound_json;

import 'dart:convert';

/// A known JSON value.
///
/// This type is an opaque type that is known to be another JSON type:
/// - [JsonString]
/// - [JsonNumber]
/// - [JsonBoolean]
/// - [JsonObject]
/// - [JsonArray]
extension type const JsonValue._(Object _value) implements Object {
  /// Parses a JSON string into a known JSON type.
  ///
  /// A [TypeError] is thrown if the value is not of the expected type.
  static T parse<T extends JsonValue?>(String source) {
    return jsonDecode(source) as T;
  }

  /// Tries to parse a JSON string into a known JSON type.
  ///
  /// Returns `null` if the value is not of the expected type.
  static T? tryParse<T extends JsonValue>(String source) {
    try {
      if (parse(source) case final T result) {
        return result;
      }
    } on FormatException {
      // Intentionally left empty.
    }
    return null;
  }
}

/// A known JSON string.
///
/// This type is essentially a [String] that can be used as a [JsonValue].
extension type const JsonString(String _value) implements JsonValue, String {
  /// Parses a JSON string into a known JSON string.
  ///
  /// A [TypeError] is thrown if the value is not a string.
  static JsonString parse(String source) {
    return JsonValue.parse(source);
  }

  /// Tries to parse a JSON string into a known JSON string.
  ///
  /// Returns `null` if the value is not a string.
  static JsonString? tryParse(String source) {
    return JsonValue.tryParse(source);
  }
}

/// A known JSON number.
///
/// This type is essentially a [num] that can be used as a [JsonValue].
extension type const JsonNumber(num _value) implements JsonValue, num {
  /// Parses a JSON string into a known JSON number.
  ///
  /// A [TypeError] is thrown if the value is not a number.
  static JsonNumber parse(String source) {
    return JsonValue.parse(source);
  }

  /// Tries to parse a JSON string into a known JSON number.
  ///
  /// Returns `null` if the value is not a number.
  static JsonNumber? tryParse(String source) {
    return JsonValue.tryParse(source);
  }
}

/// A known JSON boolean.
///
/// This type is essentially a [bool] that can be used as a [JsonValue].
extension type const JsonBoolean(bool _value) implements JsonValue, bool {
  /// Parses a JSON string into a known JSON boolean.
  ///
  /// A [TypeError] is thrown if the value is not a boolean.
  static JsonBoolean parse(String source) {
    return JsonValue.parse(source);
  }

  /// Tries to parse a JSON string into a known JSON boolean.
  ///
  /// Returns `null` if the value is not a boolean.
  static JsonBoolean? tryParse(String source) {
    return JsonValue.tryParse(source);
  }
}

/// A known JSON object.
///
/// This type is essentially a [Map] that can be used as a [JsonValue].
extension type const JsonObject(Map<String, JsonValue?> _fields)
    implements JsonValue, Map<String, JsonValue?> {
  /// Parses a JSON string into a known JSON object.
  ///
  /// A [TypeError] is thrown if the value is not an object.
  static JsonObject parse(String source) {
    return JsonValue.parse(source);
  }

  /// Tries to parse a JSON string into a known JSON object.
  ///
  /// Returns `null` if the value is not an object.
  static JsonObject? tryParse(String source) {
    return JsonValue.tryParse(source);
  }

  /// Returns the value of the field with the given [key].
  ///
  /// Throws an error if the field is missing.
  T get<T extends JsonValue?>(String key) {
    final value = this[key];
    if (value == null && !containsKey(key)) {
      throw StateError('Field "$key" is missing');
    }
    return value as T;
  }

  /// Returns the string value of the field with the given [key].
  ///
  /// Throws an error if the field is not a string.
  JsonString string(String key) => get(key);

  /// Returns the number value of the field with the given [key].
  ///
  /// Throws an error if the field is not a number.
  JsonNumber number(String key) => get(key);

  /// Returns the boolean value of the field with the given [key].
  ///
  /// Throws an error if the field is not a boolean.
  JsonBoolean boolean(String key) => get(key);

  /// Returns the object value of the field with the given [key].
  ///
  /// Throws an error if the field is not an object.
  JsonObject object(String key) => get(key);

  /// Returns the array value of the field with the given [key].
  ///
  /// Throws an error if the field is not an array.
  JsonArray<T> array<T extends JsonValue?>(String key) => get(key);
}

/// A known JSON array.
///
/// This type is essentially a [List] that can be used as a [JsonValue].
extension type const JsonArray<T extends JsonValue?>(List<T> _elements)
    implements JsonValue, List<T> {
  /// Parses a JSON string into a known JSON array.
  ///
  /// A [TypeError] is thrown if the value is not an array.
  static JsonArray<T> parse<T extends JsonValue?>(String source) {
    return JsonValue.parse(source);
  }

  /// Tries to parse a JSON string into a known JSON array.
  ///
  /// Returns `null` if the value is not an array.
  static JsonArray<T>? tryParse<T extends JsonValue>(String source) {
    return JsonValue.tryParse(source);
  }
}
