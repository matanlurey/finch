import 'dart:convert';

import 'package:finch/src/utils/sound_json.dart';
import 'package:http/http.dart' as http;

/// A REST client for accessing the GitHub API.
///
/// This class is a wrapper around the `http` package, and provides methods for
/// making requests to the GitHub API, with appropriate headers, authentication,
/// and error handling.
///
/// For an example of usage, see [getJson].
///
/// ## Safety
///
/// The [close] method should be called when the client is no longer needed, to
/// ensure that the underlying HTTP client is closed and its resources are
/// released, otherwise the application may hang.
interface class RestClient {
  final Uri _baseUrl;
  final http.Client _http;
  final Map<String, String> _headers;

  RestClient.withPersonalAccessToken(
    String token, {
    Uri? baseUri,
    http.Client? httpClient,
  })  : _baseUrl = baseUri ?? Uri.https('api.github.com'),
        _headers = {
          'Authorization': 'Token $token',
          'Accept': 'application/vnd.github.v3+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
        _http = httpClient ?? http.Client();

  /// Closes the underlying HTTP client.
  void close() {
    _http.close();
  }

  /// Sends a GET request to the specified [path] and returns the JSON response.
  ///
  /// The optional [query] parameter can be used to specify query parameters.
  ///
  /// ## Examples
  ///
  /// ```dart
  /// final client = RestClient.withPersonalAccessToken('my-token');
  /// try {
  ///   final response = await client.getJson<Map<String, Object?>>('/user');
  ///   print(response['login']); // octocat
  /// } finally {
  ///   // Always close the client when done.
  ///   client.close();
  /// }
  /// ```
  ///
  /// ## Errors
  ///
  /// - Throws [http.ClientException] if the request fails.
  Future<T> getJson<T extends JsonValue?>(
    String path, [
    Map<String, String>? query,
  ]) async {
    final url = _baseUrl.replace(path: path, queryParameters: query);
    final result = await _http.read(url, headers: _headers);
    return json.decode(result) as T;
  }
}
