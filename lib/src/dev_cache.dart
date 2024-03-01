import 'dart:convert';
import 'dart:io' as io;

import 'package:finch/src/github.dart';
import 'package:finch/src/utils/sound_json.dart';
import 'package:path/path.dart' as p;

final class CachedRestClient implements RestClient {
  static final io.Directory cacheDir = () {
    final pubspec = io.File('pubspec.yaml');
    if (!pubspec.existsSync() ||
        !pubspec.readAsStringSync().contains(RegExp(r'name:\s+finch\b'))) {
      throw StateError('Refusing to use cache outside of the finch package.');
    }
    final dir = io.Directory(
      p.join('.dart_tool', 'finch', 'cache'),
    )..createSync(recursive: true);
    io.stderr.writeln('Using cache at ${dir.path}...');
    return dir;
  }();

  final RestClient _inner;

  CachedRestClient(RestClient inner) : _inner = inner;

  @override
  void close() {
    _inner.close();
  }

  @override
  Future<T> getJson<T extends JsonValue?>(
    String path, [
    Map<String, String>? query,
  ]) async {
    final cacheFile = _cacheFile(path, query);
    if (cacheFile.existsSync()) {
      return jsonDecode(cacheFile.readAsStringSync()) as T;
    }
    final response = await _inner.getJson<T>(path, query);
    // Make the directory if it doesn't exist.
    cacheFile.parent.createSync(recursive: true);
    cacheFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(response),
    );
    return response;
  }

  String _cacheValue(String value) {
    // Remove any characters not valid in a file name.
    return value.replaceAll(RegExp('[^a-zA-Z0-9]'), '_');
  }

  io.File _cacheFile(String path, Map<String, String>? query) {
    var file = p.join(cacheDir.path, path.replaceAll('/', p.separator));
    if (query != null) {
      file = '${file}__';
      for (final key in query.keys.toList()..sort()) {
        file = '$file${key}_${_cacheValue(query[key]!)}_';
      }
    }
    return io.File('$file.json');
  }
}
