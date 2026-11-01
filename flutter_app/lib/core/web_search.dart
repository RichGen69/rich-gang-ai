import 'dart:convert';
import 'package:http/http.dart' as http;

/// One real search result, exactly as a provider returned it.
class SearchResult {
  const SearchResult(this.title, this.snippet, this.url, this.source);
  final String title;
  final String snippet;
  final String url;

  /// Provider name: 'duckduckgo' or 'wikipedia'.
  final String source;

  Map<String, dynamic> toJson() =>
      {'title': title, 'snippet': snippet, 'url': url, 'source': source};
}

class SearchUnavailable implements Exception {
  SearchUnavailable(this.message);
  final String message;
  @override
  String toString() => 'SearchUnavailable: $message';
}

/// Real-time web search for the agents — Richard's requirement,
/// built under his no-mock rule:
///
/// Providers (both keyless, both verified live from this project on
/// 2026-10-21 by direct request):
/// 1. DuckDuckGo Instant Answer API (api.duckduckgo.com) — returns
///    an abstract + related topics for entity/factual queries.
/// 2. Wikipedia OpenSearch + REST summary — encyclopaedic fallback.
///
/// HONEST LIMITS, in the open: keyless Instant Answer is NOT a full
/// web index. News, prices, scores and other fast-moving queries may
/// return nothing here. When nothing is found this service returns
/// an EMPTY list or throws [SearchUnavailable] — it never invents a
/// result, a snippet, or a URL. A keyed full-index provider (Brave /
/// Tavily / Serper) is the upgrade slot documented in
/// docs/CHARACTER_AI.md; until a key exists in secure storage, this
/// is the real, limited search the agents actually have, and the
/// agents say so when a search comes back empty.
class WebSearchService {
  WebSearchService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _ua = 'RichGangAI/0.1 (personal build; character agents)';

  /// Time-sensitive / external-fact markers. Lexical heuristic —
  /// labelled as such, same discipline as the affect appraisal.
  static const _searchCues = [
    'today', 'tonight', 'latest', 'news', 'current', 'now', 'price',
    'score', 'weather', 'who is', 'what is', 'when is', 'when did',
    'search', 'look up', 'find out', 'happened', 'released', 'won',
    'election', 'stock', 'bitcoin', 'trending', 'update on',
  ];

  /// Heuristic: does this message need facts from outside the room?
  static bool needsSearch(String text) {
    final t = text.toLowerCase();
    return _searchCues.any(t.contains);
  }

  Future<List<SearchResult>> search(String query,
      {int limit = 5}) async {
    final results = <SearchResult>[];
    Object? lastError;
    try {
      results.addAll(await _duckDuckGo(query));
    } catch (e) {
      lastError = e;
    }
    if (results.length < limit) {
      try {
        results.addAll(await _wikipedia(query));
      } catch (e) {
        lastError ??= e;
      }
    }
    if (results.isEmpty && lastError != null) {
      throw SearchUnavailable(
          'both search providers failed for "$query" ($lastError)');
    }
    // De-duplicate by URL, keep provider order.
    final seen = <String>{};
    return [
      for (final r in results)
        if (seen.add(r.url)) r,
    ].take(limit).toList();
  }

  Future<List<SearchResult>> _duckDuckGo(String query) async {
    final uri = Uri.https('api.duckduckgo.com', '/', {
      'q': query,
      'format': 'json',
      'no_html': '1',
      'skip_disambig': '0',
    });
    final r = await _client
        .get(uri, headers: {'User-Agent': _ua})
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) {
      throw SearchUnavailable('DuckDuckGo HTTP ${r.statusCode}');
    }
    return parseDuckDuckGo(r.body);
  }

  /// Pure parser — unit-tested against the API's real shape.
  static List<SearchResult> parseDuckDuckGo(String body) {
    final doc = jsonDecode(body) as Map<String, dynamic>;
    final out = <SearchResult>[];
    final abstract = (doc['AbstractText'] as String? ?? '').trim();
    final abstractUrl = (doc['AbstractURL'] as String? ?? '').trim();
    if (abstract.isNotEmpty && abstractUrl.isNotEmpty) {
      out.add(SearchResult(
        (doc['Heading'] as String? ?? 'Result').trim(),
        abstract,
        abstractUrl,
        'duckduckgo',
      ));
    }
    final topics = doc['RelatedTopics'];
    if (topics is List) {
      for (final t in topics) {
        if (t is! Map<String, dynamic>) continue;
        final url = (t['FirstURL'] as String? ?? '').trim();
        final text = (t['Text'] as String? ?? '').trim();
        if (url.isEmpty || text.isEmpty) continue;
        out.add(SearchResult(text.split(' - ').first, text, url, 'duckduckgo'));
      }
    }
    return out;
  }

  Future<List<SearchResult>> _wikipedia(String query) async {
    final uri = Uri.https('en.wikipedia.org', '/w/api.php', {
      'action': 'opensearch',
      'search': query,
      'limit': '5',
      'format': 'json',
    });
    final r = await _client
        .get(uri, headers: {'User-Agent': _ua})
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) {
      throw SearchUnavailable('Wikipedia HTTP ${r.statusCode}');
    }
    return parseWikipedia(r.body);
  }

  /// Pure parser for Wikipedia OpenSearch: [query, [titles],
  /// [descriptions], [urls]].
  static List<SearchResult> parseWikipedia(String body) {
    final doc = jsonDecode(body) as List<dynamic>;
    if (doc.length < 4) return const [];
    final titles = (doc[1] as List<dynamic>).cast<String>();
    final descs = (doc[2] as List<dynamic>).cast<String>();
    final urls = (doc[3] as List<dynamic>).cast<String>();
    return [
      for (var i = 0; i < titles.length && i < urls.length; i++)
        SearchResult(
          titles[i],
          i < descs.length ? descs[i] : '',
          urls[i],
          'wikipedia',
        ),
    ];
  }

  /// Format real results for a prompt. Empty results format as an
  /// explicit "no results" instruction so the agent says it found
  /// nothing instead of filling the gap from memory-as-fact.
  static String formatForPrompt(String query, List<SearchResult> results) {
    if (results.isEmpty) {
      return 'WEB SEARCH for "$query": no results were returned. '
          'Say plainly that the search came back empty; do not state '
          'outside facts about this from memory as if they were found.';
    }
    final lines = [
      'WEB SEARCH for "$query" — real results fetched just now. '
          'Use these, and name the source you use:',
    ];
    for (final r in results) {
      lines.add('- ${r.title} — ${r.snippet} [source: ${r.source}, ${r.url}]');
    }
    return lines.join('\n');
  }
}
