import 'dart:io' as io;

import 'package:finch/src/elapsed_time.dart';
import 'package:finch/src/github/rest_client.dart';
import 'package:meta/meta.dart';

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
    await _run(client);
  } finally {
    client.close();
  }
}

Future<void> _run(RestClient client) async {
  final String login;
  {
    final response = await client.getJson<Map<String, Object?>>('/user');
    if (response['login'] case final String value) {
      login = value;
    } else {
      throw StateError('Expected a "login" field in the response.');
    }
  }

  io.stderr.writeln('Hello, $login!');

  // Search for open pull requests, and merge them with:
  // - pull request details
  // - review status
  // - check status
  final statuses = <PullRequestStatus>[];
  {
    final response = await client.getJson<Map<String, Object?>>(
      '/search/issues',
      {
        'q': [
          'is:pr',
          'is:open',
          'archived:false',
          'repo:flutter/engine',
          'author:$login',
        ].join(' '),
      },
    );

    final items = (response['items']! as List).cast<Map<String, Object?>>();
    for (final item in items) {
      final number = item['number']! as int;
      final title = item['title']! as String;
      final url = Uri.parse(item['html_url']! as String);
      final reviews = await _getReviewStatus(client, number);
      final checks = await _getCheckStatus(client, number);

      statuses.add(
        PullRequestStatus(
          number: number,
          title: title,
          url: url,
          reviews: reviews,
          checks: checks,
        ),
      );
    }
  }

  // Prints out the following table:
  //
  // %{number} | %{title}
  // %{review_status}
  // %{check_status}
  //
  // %{review_status} is either:
  // ⚪ no reviewer assigned
  // 🟡 waiting for review from %{reviewers_count} reviewers (%{duration_waiting})
  // 🟢 approved by %{reviewers_approved}/%{reviewers_count} reviewers
  // 🔴 changes requested by %{reviewers_count} reviewers (%{duration})
  //
  // %{check_status} is either:
  // 🟡 waiting for %{checks_succeeded} / %{checks_total} (%{duration_waiting})
  // 🟢 checks passed
  // 🔴 checks failed (%{checks_failed} / %{checks_total}
  for (final status in statuses) {
    io.stdout.writeln('\n$status');
  }
}

Future<PullRequestReviewStatus> _getReviewStatus(
  RestClient client,
  int number,
) async {
  final response = await client.getJson<List<Object?>>(
    '/repos/flutter/engine/pulls/$number/reviews',
  );

  final reviews = response.cast<Map<String, Object?>>();

  if (reviews.isEmpty) {
    return const ReviewPendingReviewers();
  }

  final approved = reviews.where((review) {
    return review['state'] == 'APPROVED';
  }).length;

  final changesRequested = reviews.where((review) {
    return review['state'] == 'CHANGES_REQUESTED';
  }).length;

  if (approved > 0) {
    return ReviewApproved(
      approved: approved,
      total: reviews.length,
    );
  }

  if (changesRequested > 0) {
    return ReviewChangesRequested(
      requested: changesRequested,
    );
  }

  final waiting = DateTime.now().difference(
    DateTime.parse(reviews.first['submitted_at']! as String),
  );

  return ReviewPendingReview(
    assigned: reviews.length,
    waiting: waiting,
  );
}

Future<PullRequestCheckStatus> _getCheckStatus(
  RestClient client,
  int number,
) async {
  // Get the pull request details.
  final response = await client.getJson<Map<String, Object?>>(
    '/repos/flutter/engine/pulls/$number',
  );

  final head = response['head']! as Map<String, Object?>;
  final sha = head['sha']! as String;

  // Get the status of the checks.
  final checks = await client.getJson<Map<String, Object?>>(
    '/repos/flutter/engine/commits/$sha/check-runs',
  );

  final runs = checks['check_runs']! as List<Object?>;
  final pending = runs.cast<Map<String, Object?>>().where((run) {
    return run['status'] == 'queued' || run['status'] == 'in_progress';
  }).length;

  final passed = runs.cast<Map<String, Object?>>().where((run) {
    return run['conclusion'] == 'success';
  }).length;

  final failed = runs.cast<Map<String, Object?>>().where((run) {
    return run['conclusion'] == 'failure';
  }).length;

  if (pending > 0) {
    // Compare started_at to current time to get the waiting duration.
    // Different checks start at different times, so treat the longest
    // waiting duration as the total waiting duration.
    final waiting = runs.cast<Map<String, Object?>>().map((run) {
      return DateTime.parse(run['started_at']! as String);
    }).reduce((a, b) => a.isAfter(b) ? a : b);

    // Compare the longest waiting duration to the current time.
    final duration = DateTime.now().difference(waiting);

    return ChecksPending(
      succeeded: passed,
      total: runs.length,
      waiting: duration,
    );
  }

  if (failed > 0) {
    return ChecksFailed(
      failed: failed,
      total: runs.length,
    );
  }

  return const ChecksPassed();
}

/// Represents a pull request and relevant status information.
@immutable
final class PullRequestStatus {
  /// The pull request number.
  final int number;

  /// The pull request title.
  final String title;

  /// The URL to the pull request.
  final Uri url;

  /// The status of the pull request review.
  final PullRequestReviewStatus reviews;

  /// The status of the pull request checks.
  final PullRequestCheckStatus checks;

  const PullRequestStatus({
    required this.number,
    required this.title,
    required this.url,
    required this.reviews,
    required this.checks,
  });

  @override
  bool operator ==(Object other) {
    return other is PullRequestStatus &&
        other.number == number &&
        other.title == title &&
        other.url == url &&
        other.reviews == reviews &&
        other.checks == checks;
  }

  @override
  int get hashCode {
    return Object.hash(number, title, url, reviews, checks);
  }

  @override
  String toString() {
    return [
      '$number | $title',
      reviews.toString(),
      checks.toString(),
    ].join('\n');
  }
}

/// Represents a pull request review status.
@immutable
sealed class PullRequestReviewStatus {
  const PullRequestReviewStatus();
}

/// No reviewer assigned.
final class ReviewPendingReviewers extends PullRequestReviewStatus {
  const ReviewPendingReviewers();

  @override
  bool operator ==(Object other) {
    return other is ReviewPendingReviewers;
  }

  @override
  int get hashCode {
    return (ReviewPendingReviewers).hashCode;
  }

  @override
  String toString() {
    return '⚪ no reviewer assigned';
  }
}

/// Waiting for review.
final class ReviewPendingReview extends PullRequestReviewStatus {
  /// The number of reviewers assigned to the pull request.
  final int assigned;

  /// How long the pull request has been waiting for review.
  final Duration waiting;

  const ReviewPendingReview({
    required this.assigned,
    required this.waiting,
  });

  @override
  bool operator ==(Object other) {
    return other is ReviewPendingReview &&
        other.assigned == assigned &&
        other.waiting == waiting;
  }

  @override
  int get hashCode {
    return Object.hash(assigned, waiting);
  }

  @override
  String toString() {
    return '🟡 waiting for review from $assigned reviewers (${waiting.toHumanReadable()})';
  }
}

/// Approved by enough reviewers to merge.
final class ReviewApproved extends PullRequestReviewStatus {
  /// The number of reviewers who approved the pull request.
  final int approved;

  /// The total number of reviewers assigned to the pull request.
  final int total;

  const ReviewApproved({
    required this.approved,
    required this.total,
  });

  @override
  bool operator ==(Object other) {
    return other is ReviewApproved &&
        other.approved == approved &&
        other.total == total;
  }

  @override
  int get hashCode {
    return Object.hash(approved, total);
  }

  @override
  String toString() {
    return '🟢 approved by $approved/$total reviewers';
  }
}

/// Changes requested by a reviewer.
final class ReviewChangesRequested extends PullRequestReviewStatus {
  /// The number of reviewers who requested changes.
  final int requested;

  const ReviewChangesRequested({
    required this.requested,
  });

  @override
  bool operator ==(Object other) {
    return other is ReviewChangesRequested && other.requested == requested;
  }

  @override
  int get hashCode {
    return requested.hashCode;
  }

  @override
  String toString() {
    return '🔴 changes requested by $requested reviewers';
  }
}

/// Represents a pull request check status.
@immutable
sealed class PullRequestCheckStatus {
  const PullRequestCheckStatus();
}

/// Checks are pending.
final class ChecksPending extends PullRequestCheckStatus {
  /// The number of checks that have succeeded.
  final int succeeded;

  /// The total number of checks.
  final int total;

  /// How long the pull request has been waiting for checks to complete.
  final Duration waiting;

  const ChecksPending({
    required this.succeeded,
    required this.total,
    required this.waiting,
  });

  @override
  bool operator ==(Object other) {
    return other is ChecksPending &&
        other.succeeded == succeeded &&
        other.total == total &&
        other.waiting == waiting;
  }

  @override
  int get hashCode {
    return Object.hash(succeeded, total, waiting);
  }

  @override
  String toString() {
    return '🟡 waiting for $succeeded/$total (${waiting.toHumanReadable()})';
  }
}

/// Checks have passed.
final class ChecksPassed extends PullRequestCheckStatus {
  const ChecksPassed();

  @override
  bool operator ==(Object other) {
    return other is ChecksPassed;
  }

  @override
  int get hashCode {
    return (ChecksPassed).hashCode;
  }

  @override
  String toString() {
    return '🟢 checks passed';
  }
}

/// Checks have failed.
final class ChecksFailed extends PullRequestCheckStatus {
  /// The number of checks that have failed.
  final int failed;

  /// The total number of checks.
  final int total;

  const ChecksFailed({
    required this.failed,
    required this.total,
  });

  @override
  bool operator ==(Object other) {
    return other is ChecksFailed &&
        other.failed == failed &&
        other.total == total;
  }

  @override
  int get hashCode {
    return Object.hash(failed, total);
  }

  @override
  String toString() {
    return '🔴 checks failed ($failed/$total)';
  }
}
