import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:finch/src/github/rest_client.dart';
import 'package:finch/src/output.dart';
import 'package:meta/meta.dart';

const _name = 'finch';
const _description = 'Opinionated workflow and tooling for hacking on Flutter.';

extension type const _JsonArray._(List<Object?> elements) implements Object {
  List<T> cast<T>() {
    return elements.cast<T>();
  }
}

extension type const _JsonObject._(Map<String, Object?> fields)
    implements Object {
  String string(String key) => any(key);
  T number<T extends num>(String key) => any(key);
  int integer(String key) => any(key);
  double float(String key) => any(key);
  bool boolean(String key) => any(key);
  _JsonObject object(String key) => any(key);
  _JsonArray array(String key) => any(key);

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

final class FinchCommandRunner extends CommandRunner<void> {
  final RestClient _github;

  FinchCommandRunner(this._github) : super(_name, _description) {
    addCommand(_StatusCommand(this));
    addCommand(_OpenCommand());
  }
}

final class _OpenCommand extends Command<void> {
  _OpenCommand() {
    argParser.addOption(
      'repo',
      abbr: 'r',
      help: 'The repository to check.',
      valueHelp: 'owner/repo',
      defaultsTo: 'flutter/engine',
    );
  }

  @protected
  String get repository => argResults!['repo'] as String;

  @override
  String get description => 'Open a PRs page in a browser.';

  @override
  String get name => 'open';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty || rest.length > 1) {
      io.stderr.writeln('Expected exactly one PR number.');
      io.exitCode = 1;
      return;
    }
    final number = int.tryParse(rest.single);
    final url = Uri.https('github.com', '/$repository/pull/$number');
    io.stdout.writeln('Opening $url...');
    await io.Process.run('open', [url.toString()]);
  }
}

final class _StatusCommand extends Command<void> {
  final FinchCommandRunner _runner;

  _StatusCommand(this._runner) {
    argParser
      ..addOption(
        'repo',
        abbr: 'r',
        help: 'The repository to check.',
        valueHelp: 'owner/repo',
        defaultsTo: 'flutter/engine',
      )
      ..addOption(
        'user',
        abbr: 'u',
        help: 'The user to check. Defaults to the authenticated user.',
        valueHelp: 'user',
      );
  }

  @protected
  String get repository => argResults!['repo'] as String;

  @protected
  String? get user => argResults!['user'] as String?;

  @override
  String get description => 'Show the status of open PRs.';

  @override
  String get name => 'status';

  Future<String> _getAuthenticatedUser() async {
    final response = await _runner._github.getJson<_JsonObject>('user');
    return response.string('login');
  }

  Future<PullRequestStatus> _fetchStatus({
    required int number,
    required String title,
    required String url,
  }) async {
    final reviews = await _fetchReviews(number);
    final checks = await _fetchChecks(number);
    return PullRequestStatus(
      number: number,
      title: title,
      url: Uri.parse(url),
      reviews: reviews,
      checks: checks,
    );
  }

  Future<PullRequestReviewStatus> _fetchReviews(int pullRequest) async {
    final response = await _runner._github.getJson<_JsonArray>(
      'repos/$repository/pulls/$pullRequest/reviews',
    );
    final reviews = response.cast<_JsonObject>();
    if (reviews.isEmpty) {
      return ReviewPendingReviewers();
    }
    final lgtm = reviews.where(
      (r) => r.string('state') == 'APPROVED',
    );
    final notYet = reviews.where(
      (r) => r.string('state') == 'CHANGES_REQUESTED',
    );
    if (notYet.isNotEmpty) {
      return ReviewChangesRequested(
        requested: notYet.length,
      );
    } else if (lgtm.isNotEmpty) {
      return ReviewApproved(
        approved: lgtm.length,
        total: reviews.length,
      );
    } else {
      // Find the earliest requested review.
      final first = reviews
          .map((r) => DateTime.parse(r.string('submitted_at')))
          .reduce((a, b) => a.isBefore(b) ? a : b);

      // Calculate the time since the earliest review was requested.
      final elapsed = DateTime.now().difference(first);

      return ReviewPendingReview(
        assigned: reviews.length,
        waiting: elapsed,
      );
    }
  }

  Future<PullRequestCheckStatus> _fetchChecks(int number) async {
    // Get the SHA of the latest commit in the pull request.
    final String sha;
    {
      final response = await _runner._github.getJson<_JsonObject>(
        'repos/$repository/pulls/$number',
      );
      sha = response.object('head').string('sha');
    }

    final response = await _runner._github.getJson<_JsonObject>(
      'repos/$repository/commits/$sha/check-runs',
    );

    final checks = response.array('check_runs').cast<_JsonObject>();
    final successful = checks.where(
      (c) =>
          c.string('conclusion') == 'success' ||
          c.string('conclusion') == 'neutral' ||
          c.string('conclusion') == 'skipped',
    );
    final failed = checks.where(
      (c) => c.string('conclusion') == 'failure',
    );

    if (failed.isNotEmpty) {
      return ChecksFailed(
        failed: failed.length,
        total: checks.length,
      );
    } else if (successful.length == checks.length) {
      // Check if we're waiting on skia-gold.
      final skiaGoldPending = await _skiaGoldPending(sha);
      if (skiaGoldPending != null) {
        // Determine waiting time.
        return ChecksPending(
          skiaGoldPending: true,
          succeeded: successful.length,
          total: checks.length + 1,
          waiting: DateTime.now().difference(skiaGoldPending),
        );
      }
      return ChecksPassed();
    } else {
      // Find the earliest check that was started.
      final first = checks
          .map((c) => DateTime.parse(c.string('started_at')))
          .reduce((a, b) => a.isBefore(b) ? a : b);

      // Calculate the time since the first check was started.
      final duration = DateTime.now().difference(first);
      final skiaGoldPending = await _skiaGoldPending(sha);

      return ChecksPending(
        skiaGoldPending: skiaGoldPending != null,
        succeeded: successful.length,
        total: checks.length + (skiaGoldPending != null ? 1 : 0),
        waiting: duration,
      );
    }
  }

  Future<DateTime?> _skiaGoldPending(String sha) async {
    final statuses = await _runner._github.getJson<_JsonArray>(
      'repos/$repository/statuses/$sha',
    );
    final gold = statuses
        .cast<_JsonObject>()
        .firstWhereOrNull((s) => s.string('context') == 'flutter-gold');
    if (gold?.string('state') == 'pending') {
      return DateTime.parse(gold!.string('updated_at'));
    }
    return null;
  }

  @override
  Future<void> run() async {
    // Check if we need to look up the authenticated user.
    final user = this.user ?? await _getAuthenticatedUser();
    io.stderr.writeln('Checking open PRs for $user in $repository...');

    // Search for open pull requests.
    final response = await _runner._github.getJson<_JsonObject>(
      'search/issues',
      {
        'q': [
          'is:pr',
          'is:open',
          'archived:false',
          'repo:$repository',
          'author:$user',
        ].join(' '),
      },
    );
    final items = response.array('items').cast<_JsonObject>();
    if (items.isEmpty) {
      io.stdout.writeln('No open PRs found.');
      return;
    }

    // Fetch the status of each pull request.
    final statuses = <PullRequestStatus>[];
    final futures = <Future<void>>[];
    for (final item in items) {
      futures.add(
        _fetchStatus(
          number: item.number('number'),
          title: item.string('title'),
          url: item.string('html_url'),
        ).then(statuses.add),
      );
    }

    // Wait for all statuses to be fetched.
    await Future.wait(futures);

    // Print the status of each pull request.
    for (final status in statuses) {
      io.stdout.writeln('\n$status');
    }
  }
}
