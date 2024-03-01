import 'package:collection/collection.dart';
import 'package:finch/src/utils/sound_json.dart';
import 'package:meta/meta.dart';

/// See: <https://docs.github.com/en/rest/search/search?apiVersion=2022-11-28#search-issues-and-pull-requests>.
@immutable
final class FindIssuesResult {
  /// Creates a new [FindIssuesResult].
  FindIssuesResult({
    required this.totalCount,
    required this.incompleteResults,
    required Iterable<FindIssuesItem> items,
  }) : items = List.unmodifiable(items);

  /// Parses a [FindIssuesResult] from JSON.
  factory FindIssuesResult.fromJson(JsonObject json) {
    return FindIssuesResult(
      totalCount: json.number('total_count').toInt(),
      incompleteResults: json.boolean('incomplete_results'),
      items: json.array<JsonObject>('items').map(FindIssuesItem.fromJson),
    );
  }

  /// The total number of issues and pull requests found.
  final int totalCount;

  /// Whether the results are incomplete.
  final bool incompleteResults;

  /// The issues and pull requests found.
  final List<FindIssuesItem> items;

  @override
  bool operator ==(Object other) {
    return other is FindIssuesResult &&
        other.totalCount == totalCount &&
        other.incompleteResults == incompleteResults &&
        const ListEquality<void>().equals(other.items, items);
  }

  @override
  int get hashCode {
    return Object.hash(
      totalCount,
      incompleteResults,
      const ListEquality<void>().hash(items),
    );
  }

  /// Returns a JSON representation of this object.
  JsonObject toJson() {
    return JsonObject({
      'total_count': JsonNumber(totalCount),
      'incomplete_results': JsonBoolean(incompleteResults),
      'items': JsonArray(items.map((e) => e.toJson()).toList()),
    });
  }
}

/// See: <https://docs.github.com/en/rest/search/search?apiVersion=2022-11-28#search-issues-and-pull-requests>.
@immutable
final class FindIssuesItem {
  /// Creates a new [FindIssuesItem].
  const FindIssuesItem({
    required this.url,
    required this.number,
    required this.title,
    required this.draft,
    required this.updatedAt,
  });

  /// Parses a [FindIssuesItem] from JSON.
  factory FindIssuesItem.fromJson(JsonObject json) {
    return FindIssuesItem(
      url: Uri.parse(json.string('url')),
      number: json.number('number').toInt(),
      title: json.string('title'),
      draft: json.get<JsonBoolean?>('draft') ?? false,
      updatedAt: DateTime.parse(json.string('updated_at')),
    );
  }

  /// The (html) URL of the issue or pull request.
  final Uri url;

  /// The number of the issue or pull request.
  final int number;

  /// The title of the issue or pull request.
  final String title;

  /// Whether this is a draft.
  ///
  /// If an issue, this is always `false`.
  final bool draft;

  /// The date and time this was last updated.
  final DateTime updatedAt;

  /// Whether this represents a pull request.
  bool get isPullRequest {
    // Check if the second to last segment of the URL is "pulls", i.e.
    // https://github.com/flutter/engine/pull/50768.
    return url.pathSegments[url.pathSegments.length - 2] == 'pulls';
  }

  /// Whether this represents an issue.
  bool get isIssue => !isPullRequest;

  @override
  bool operator ==(Object other) {
    return other is FindIssuesItem &&
        other.url == url &&
        other.number == number &&
        other.title == title &&
        other.draft == draft &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(url, number, title, draft, updatedAt);
  }

  ///
  JsonObject toJson() {
    return JsonObject({
      'url': JsonString(url.toString()),
      'number': JsonNumber(number),
      'title': JsonString(title),
      if (isPullRequest) 'draft': JsonBoolean(draft),
      'updated_at': JsonString(updatedAt.toIso8601String()),
    });
  }
}
