import 'dart:io' as io;

import 'package:finch/src/command_runner.dart';
import 'package:finch/src/github/rest_client.dart';
import 'package:http/http.dart';
import 'package:stack_trace/stack_trace.dart';

void main(List<String> args) async {
  // Check for the environment variable GITHUB_TOKEN (required for now).
  final RestClient client;
  {
    if (io.Platform.environment['GITHUB_TOKEN'] case final String token) {
      client = RestClient.withPersonalAccessToken(token);
    } else {
      io.stdout.writeln('The GITHUB_TOKEN environment variable is required.');
      io.stderr.writeln(
        'See https://docs.github.com/en/authentication/'
        'keeping-your-account-and-data-secure/'
        'managing-your-personal-access-tokens',
      );
      io.exitCode = 1;
      return;
    }
  }

  try {
    await FinchCommandRunner(client).run(args);
  } on ClientException catch (e, s) {
    io.stderr.writeln('Error: ${e.message}');
    io.stderr.writeln('Stack trace:\n${Trace.from(s).terse}');
    io.exitCode = 1;
  } finally {
    client.close();
  }
}
