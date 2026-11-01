import 'web_search.dart';

/// Deep seek — the deep-search counterpart to deep reasoning.
///
/// A normal agent turn runs ONE search with the user's words. Deep
/// seek decomposes the question into several sub-queries, searches
/// each against the real providers, merges and de-duplicates the
/// results, and reports exactly which sub-queries came back empty —
/// coverage is shown, not smoothed over.
///
/// Decomposition is lexical/structural (question-type templates over
/// the extracted subject), labelled as such: it is a real, testable
/// procedure, not an LLM "planning" claim. If inference is available
/// the caller may ADD model-proposed sub-queries, but the base set
/// below always runs, so deep seek works fully offline of the model.
class DeepSeek {
  DeepSeek({WebSearchService? search}) : search = search ?? WebSearchService();
  final WebSearchService search;

  static final _stopwords = {
    'what', 'who', 'when', 'where', 'why', 'how', 'is', 'are', 'was',
    'were', 'the', 'a', 'an', 'of', 'to', 'in', 'on', 'for', 'and',
    'or', 'about', 'tell', 'me', 'did', 'does', 'do', 'can', 'you',
    'latest', 'news', 'current', 'today', 'find', 'out', 'search',
    'look', 'up',
  };

  /// Extract the subject keywords from a question (lexical).
  static List<String> subjectWords(String question) => question
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2 && !_stopwords.contains(w))
      .toList();

  /// The sub-query set for a question. Pure — unit-tested.
  static List<String> decompose(String question) {
    final words = subjectWords(question);
    final subject = words.take(6).join(' ');
    if (subject.isEmpty) return [question.trim()];
    final q = question.toLowerCase();
    final subs = <String>{subject};
    if (q.contains('price') || q.contains('stock') || q.contains('cost')) {
      subs.add('$subject price today');
      subs.add('$subject market news');
    } else if (q.contains('who')) {
      subs.add('$subject biography');
      subs.add('$subject latest news');
    } else if (q.contains('when')) {
      subs.add('$subject date schedule');
      subs.add('$subject latest update');
    } else {
      subs.add('$subject latest news');
      subs.add('$subject background');
    }
    return subs.toList();
  }

  Future<DeepSeekReport> seek(String question, {int perQuery = 3}) async {
    final subs = decompose(question);
    final byUrl = <String, SearchResult>{};
    final empty = <String>[];
    final failed = <String>[];
    for (final sub in subs) {
      try {
        final results = await search.search(sub, limit: perQuery);
        if (results.isEmpty) empty.add(sub);
        for (final r in results) {
          byUrl[r.url] = r;
        }
      } on SearchUnavailable {
        failed.add(sub);
      }
    }
    return DeepSeekReport(
      question: question,
      subQueries: subs,
      results: byUrl.values.toList(),
      emptySubQueries: empty,
      failedSubQueries: failed,
    );
  }
}

class DeepSeekReport {
  const DeepSeekReport({
    required this.question,
    required this.subQueries,
    required this.results,
    required this.emptySubQueries,
    required this.failedSubQueries,
  });
  final String question;
  final List<String> subQueries;
  final List<SearchResult> results;
  final List<String> emptySubQueries;
  final List<String> failedSubQueries;

  /// Prompt block: real results + honest coverage statement.
  String formatForPrompt() {
    final lines = [
      'DEEP SEEK on "$question" — ${subQueries.length} sub-queries '
          'searched: ${subQueries.join(' | ')}.',
    ];
    if (emptySubQueries.isNotEmpty) {
      lines.add('Sub-queries with NO results: '
          '${emptySubQueries.join(' | ')}. Do not fill those gaps '
          'from memory as if they were found.');
    }
    if (failedSubQueries.isNotEmpty) {
      lines.add('Sub-queries whose search FAILED: '
          '${failedSubQueries.join(' | ')}.');
    }
    if (results.isEmpty) {
      lines.add('No results at all. Say the deep seek came back '
          'empty.');
    } else {
      for (final r in results) {
        lines.add(
            '- ${r.title} — ${r.snippet} [source: ${r.source}, ${r.url}]');
      }
    }
    return lines.join('\n');
  }
}
