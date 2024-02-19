import 'package:finch/src/elapsed_time.dart';
import 'package:meta/meta.dart';

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
    return '🟡 waiting for $succeeded/$total checks (${waiting.toHumanReadable()})';
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
