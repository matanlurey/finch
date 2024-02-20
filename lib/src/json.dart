extension type const JsonArray._(List<Object?> elements) implements Object {
  List<T> cast<T>() {
    return elements.cast<T>();
  }
}

extension type const JsonObject._(Map<String, Object?> fields)
    implements Object {
  String string(String key) => any(key);
  T number<T extends num>(String key) => any(key);
  int integer(String key) => any(key);
  double float(String key) => any(key);
  bool boolean(String key) => any(key);
  JsonObject object(String key) => any(key);
  JsonArray array(String key) => any(key);

  T any<T extends Object?>(String key) {
    final value = fields[key];
    if (value == null && !fields.containsKey(key)) {
      throw ArgumentError.value(key, 'key', 'Key not found in map.');
    }
    if (value is T) {
      return value;
    }
    throw ArgumentError.value(value, 'value', 'Value is not of type $T.');
  }
}
