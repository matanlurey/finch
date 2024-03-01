import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:finch/src/dev_cache.dart';
import 'package:finch/src/github/rest_client.dart';
import 'package:finch/src/logger.dart';
import 'package:finch/src/output.dart';
import 'package:finch/src/utils/sound_json.dart';
import 'package:meta/meta.dart';

const _name = 'finch';
const _description = 'Opinionated workflow and tooling for hacking on Flutter.';

final class FinchCommandRunner extends CommandRunner<void> {
  late final Logger _logger;

  late RestClient _github;

  FinchCommandRunner(this._github) : super(_name, _description) {
    addCommand(_DevCommand());
    addCommand(_StatusCommand(this));
    addCommand(_OpenCommand(this));
    argParser
      ..addFlag(
        'cache',
        help: 'Enables a simple development cache of all GET requests.',
        hide: true,
      )
      ..addOption(
        'verbose',
        abbr: 'v',
        help: 'Sets the verbosity level of the logger.',
        allowed: Verbosity.values.map((v) => v.name),
        defaultsTo: Verbosity.error.name,
      );
  }

  @override
  Future<void> runCommand(ArgResults topLevelResults) async {
    _logger = Logger(
      switch (topLevelResults['verbose'] as String?) {
        'fatal' || null => Verbosity.fatal,
        'error' => Verbosity.error,
        'warning' => Verbosity.warning,
        'info' || '' => Verbosity.info,
        'debug' => Verbosity.debug,
        final unknown => throw FatalError('Unknown verbosity level: $unknown'),
      },
    );
    if (topLevelResults['cache'] as bool) {
      _github = CachedRestClient(_github);
    }
    return super.runCommand(topLevelResults);
  }
}

final class _OpenCommand extends Command<void> {
  final FinchCommandRunner _runner;

  _OpenCommand(this._runner) {
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
    if (rest.isEmpty || rest.length > 1) {}
    final number = int.tryParse(rest.single);
    final url = Uri.https('github.com', '/$repository/pull/$number');
    _runner._logger.info('Opening $url...');
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
      )
      ..addFlag(
        'show-drafts',
        abbr: 'd',
        help: 'Show draft PRs.',
      );
  }

  @protected
  String get repository => argResults!['repo'] as String;

  @protected
  String? get user => argResults!['user'] as String?;

  @protected
  bool get showDrafts => argResults!['show-drafts'] as bool;

  @override
  String get description => 'Show the status of open PRs.';

  @override
  String get name => 'status';

  Future<String> _getAuthenticatedUser() async {
    final response = await _runner._github.getJson<JsonObject>('user');
    return response.string('login');
  }

  Future<PullRequestStatus> _fetchStatus({
    required int number,
    required String title,
    required String url,
    required bool draft,
    required DateTime lastUpdated,
  }) async {
    final reviews = await _fetchReviews(number, lastUpdated);
    final checks = await _fetchChecks(number);
    return PullRequestStatus(
      number: number,
      title: title,
      url: Uri.parse(url),
      reviews: reviews,
      checks: checks,
      isDraft: draft,
    );
  }

  Future<PullRequestReviewStatus> _fetchReviews(
    int pullRequest,
    DateTime lastUpdated,
  ) async {
    final response = await _runner._github.getJson<JsonArray>(
      'repos/$repository/pulls/$pullRequest/reviews',
    );
    final requested = await _runner._github.getJson<JsonObject>(
      'repos/$repository/pulls/$pullRequest/requested_reviewers',
    );
    final reviews = response.cast<JsonObject>();
    final requestedReviewers = requested.array('users').cast<JsonObject>();
    if (reviews.isEmpty && requestedReviewers.isEmpty) {
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
        total: lgtm.length + requestedReviewers.length,
      );
    } else {
      // Use the last update time for the PR as the time we started waiting,
      // as there is no other good time to use (requested reviews do not include
      // a timestamp).
      return ReviewPendingReview(
        assigned: requestedReviewers.length,
        waiting: DateTime.now().difference(lastUpdated),
      );
    }
  }

  Future<PullRequestCheckStatus> _fetchChecks(int number) async {
    // Get the SHA of the latest commit in the pull request.
    final String sha;
    {
      final response = await _runner._github.getJson<JsonObject>(
        'repos/$repository/pulls/$number',
      );
      sha = response.object('head').string('sha');
    }

    final response = await _runner._github.getJson<JsonObject>(
      'repos/$repository/commits/$sha/check-runs',
    );

    final checks = response.array('check_runs').cast<JsonObject>();
    final successful = checks.where(
      (c) =>
          c.get('conclusion') == JsonString('success') ||
          c.get('conclusion') == JsonString('neutral') ||
          c.get('conclusion') == JsonString('skipped'),
    );
    final failed = checks.where(
      (c) => c.get('conclusion') == JsonString('failure'),
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
    final statuses = await _runner._github.getJson<JsonArray>(
      'repos/$repository/statuses/$sha',
    );
    final gold = statuses
        .cast<JsonObject>()
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
    _runner._logger.info('Checking open PRs for $user in $repository...');

    // Search for open pull requests.
    final response = await _runner._github.getJson<JsonObject>(
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
    final items = response.array('items').cast<JsonObject>();
    if (items.isEmpty) {
      io.stdout.writeln('No open PRs found.');
      return;
    }

    // Fetch the status of each pull request.
    final statuses = <PullRequestStatus>[];
    final futures = <Future<void>>[];
    var draftsHidden = 0;
    for (final item in items) {
      futures.add(
        _fetchStatus(
          number: item.number('number').toInt(),
          title: item.string('title'),
          url: item.string('html_url'),
          draft: item.boolean('draft'),
          lastUpdated: DateTime.parse(item.string('updated_at')),
        ).then((status) {
          if (!showDrafts && status.isDraft) {
            draftsHidden++;
            return;
          }
          statuses.add(status);
        }),
      );
    }

    // Wait for all statuses to be fetched.
    await Future.wait(futures);

    // Print the status of each pull request.
    for (final status in statuses) {
      io.stdout.writeln('\n$status');
    }

    if (draftsHidden > 0) {
      _runner._logger.info(
        '\n'
        'TIP: $draftsHidden draft PRs hidden. Use --show-drafts',
      );
    }
  }
}

final class _DevCommand extends Command<void> {
  _DevCommand() {
    addSubcommand(_DevCacheClearCommand());
  }

  @override
  bool get hidden => true;

  @override
  String get description => 'Subcommands for development tasks.';

  @override
  String get name => 'dev';
}

final class _DevCacheClearCommand extends Command<void> {
  @override
  String get description => 'Clear the development cache.';

  @override
  String get name => 'cache-clear';

  @override
  Future<void> run() async {
    final cacheDir = io.Directory('.dart_tool/finch/cache');
    if (cacheDir.existsSync()) {
      cacheDir.deleteSync(recursive: true);
    }
  }
}
