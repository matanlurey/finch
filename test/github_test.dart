import 'dart:convert';

import 'package:finch/src/github/rest_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  test('RestClient makes a valid github API request', () async {
    final base = _FakeBaseClient((request) {
      expect(request.url, Uri.https('api.github.com', '/user'));
      expect(request.headers, {
        'Authorization': 'Token my-token',
        'Accept': 'application/vnd.github.v3+json',
        'X-GitHub-Api-Version': '2022-11-28',
      });
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"login":"octocat"}')),
        200,
      );
    });

    final rest = RestClient.withPersonalAccessToken(
      'my-token',
      httpClient: base,
    );

    expect(
      await rest.getJson<Map<String, Object?>>('/user'),
      {'login': 'octocat'},
    );

    rest.close();
  });
}

final class _FakeBaseClient extends http.BaseClient {
  final http.StreamedResponse Function(http.BaseRequest) _handler;

  _FakeBaseClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return _handler(request);
  }
}
