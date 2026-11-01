import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:rich_gang_ai/core/affect_engine.dart';
import 'package:rich_gang_ai/core/avatar_stage.dart';
import 'package:rich_gang_ai/core/character.dart';
import 'package:rich_gang_ai/core/deep_search.dart';
import 'package:rich_gang_ai/core/roundtable.dart';
import 'package:rich_gang_ai/core/thinking.dart';
import 'package:rich_gang_ai/core/time_awareness.dart';
import 'package:rich_gang_ai/core/voice_engine.dart';
import 'package:rich_gang_ai/core/web_search.dart';

const _fixture = '''
{"version":1,"characters":[
 {"id":"alpha","name":"Alpha","display_name":"Alpha A","title":"Tester",
  "roles":["butler","conversational"],"core":"core","personality":"p",
  "speech_style":"s","interests":["music","data"],
  "talkativeness":0.5,"volatility":0.5,
  "baseline":{"pleasure":0.1,"arousal":0.2,"dominance":0.3},
  "age_gated":false,
  "voice":{"display":"A","eleven_labs_voice_id":"x",
   "eleven_labs_voice_name":"Dave","kokoro_voice":"am_michael",
   "system_pitch":1.0,"system_rate":0.5,"stability":0.5,"style":0.3}},
 {"id":"beta","name":"Beta","display_name":"Beta B","title":"Tester 2",
  "roles":["companion"],"core":"core","personality":"p",
  "speech_style":"s","interests":["romance","music"],
  "talkativeness":0.9,"volatility":0.9,
  "baseline":{"pleasure":0.5,"arousal":0.4,"dominance":0.2},
  "age_gated":true,
  "voice":{"display":"B","eleven_labs_voice_id":"y",
   "eleven_labs_voice_name":"Aria","kokoro_voice":"af_bella",
   "system_pitch":1.1,"system_rate":0.47,"stability":0.3,"style":0.6}}
]}''';

void main() {
  final registry = CharacterRegistry.parse(_fixture);
  final alpha = registry.byId('alpha')!;
  final beta = registry.byId('beta')!;

  group('characters', () {
    test('parse roster, roles, age gate', () {
      expect(registry.all.length, 2);
      expect(alpha.roles, contains(CharacterRole.butler));
      expect(beta.ageGated, isTrue);
      expect(registry.byRole(CharacterRole.companion).single.id, 'beta');
    });
  });

  group('affect engine', () {
    test('baseline emotion derives and praise moves pleasure up', () {
      final s = AffectState(alpha);
      final before = s.current.pleasure;
      s.appraise(AffectEvent.praised);
      expect(s.current.pleasure, greaterThan(before));
    });

    test('lexical appraisal only fires on real cues', () {
      final s = AffectState(alpha);
      expect(s.appraiseText('the weather is mild'), isEmpty);
      final fired = s.appraiseText('thank you, that was great');
      expect(fired, contains(AffectEvent.thanked));
      expect(fired, contains(AffectEvent.praised));
    });

    test('decay moves state toward baseline with elapsed time', () {
      final s = AffectState(alpha);
      s.appraise(AffectEvent.insulted);
      final angry = s.current.pleasure;
      s.updatedAt = DateTime.now().subtract(const Duration(days: 2));
      s.decay(DateTime.now());
      expect(s.current.pleasure, greaterThan(angry));
      expect((s.current.pleasure - s.baseline.pleasure).abs(),
          lessThan((angry - s.baseline.pleasure).abs()));
    });

    test('snapshot round-trips through JSON', () {
      final engine = AffectEngine(registry);
      engine.of('alpha').appraise(AffectEvent.praised);
      final snap = engine.snapshot();
      final restored = AffectEngine(registry)..restore(snap);
      expect(restored.of('alpha').current.pleasure,
          closeTo(engine.of('alpha').current.pleasure, 0.001));
    });

    test('every prototype emotion is reachable in range', () {
      for (final e in emotionPrototypes.entries) {
        final s = AffectState(alpha)..current = e.value;
        final reading = s.emotion;
        expect(reading.emotion, e.key);
        expect(reading.intensity, greaterThan(0.9));
      }
    });
  });

  group('turn engine', () {
    test('addressed agent beats unaddressed, last speaker penalised', () {
      final engine = TurnEngine(math.Random(42));
      final affects = {
        'alpha': AffectState(alpha),
        'beta': AffectState(beta),
      };
      // Beta spoke last AND alpha was addressed by name in beta's line.
      final pick = engine.pick(
        [alpha, beta],
        affects,
        topic: 'music',
        lastText: 'Alpha, what do you think about that take?',
        lastSpeakerId: 'beta',
        turnsSinceSpoke: const {'alpha': 3, 'beta': 0},
      );
      expect(pick.id, 'alpha');
    });

    test('agent-chosen topic comes from shared interests', () {
      expect(TurnEngine.chooseTopic([alpha, beta]),
          contains('music'));
    });
  });

  group('web search parsing', () {
    test('duckduckgo abstract + topics parse, empties stay empty', () {
      const body = '{"AbstractText":"Houston is a city in Texas.",'
          '"AbstractURL":"https://en.wikipedia.org/wiki/Houston",'
          '"Heading":"Houston","RelatedTopics":['
          '{"FirstURL":"https://duckduckgo.com/Houston",'
          '"Text":"Houston, Texas"}]}';
      final r = WebSearchService.parseDuckDuckGo(body);
      expect(r.length, 2);
      expect(r.first.url, contains('wikipedia'));
      expect(WebSearchService.parseDuckDuckGo(
          '{"AbstractText":"","AbstractURL":"","RelatedTopics":[]}'),
          isEmpty);
    });

    test('wikipedia opensearch parses the real shape', () {
      const body = '["Dallas",["Dallas","Dallas Cowboys"],["",""],'
          '["https://en.wikipedia.org/wiki/Dallas",'
          '"https://en.wikipedia.org/wiki/Dallas_Cowboys"]]';
      final r = WebSearchService.parseWikipedia(body);
      expect(r.length, 2);
      expect(r.last.title, 'Dallas Cowboys');
    });

    test('needsSearch is a lexical heuristic', () {
      expect(WebSearchService.needsSearch('what is the latest news'),
          isTrue);
      expect(WebSearchService.needsSearch('tell me a story'), isFalse);
    });
  });

  group('deep seek decomposition', () {
    test('price questions get market sub-queries', () {
      final subs = DeepSeek.decompose('What is the bitcoin price?');
      expect(subs.any((s) => s.contains('price today')), isTrue);
      expect(subs.length, greaterThanOrEqualTo(3));
    });

    test('subject words strip stopwords', () {
      expect(DeepSeek.subjectWords('Who is the mayor of Houston?'),
          contains('mayor'));
      expect(DeepSeek.subjectWords('Who is the mayor of Houston?'),
          isNot(contains('who')));
    });
  });

  group('thought step', () {
    test('parses a well-formed think JSON, rejects junk', () {
      const raw = '{"situation":"s","feeling":"f","memory":"m",'
          '"goal":"g","options":["a","b"],"chosen":"a","why":"w"}';
      final t = ThoughtStep.tryParse(raw);
      expect(t, isNotNull);
      expect(t!.summary, contains('chose: a'));
      expect(ThoughtStep.tryParse('not json at all'), isNull);
      expect(ThoughtStep.tryParse('{"situation":"s"}'), isNull);
    });
  });

  group('time awareness', () {
    test('clock line + gap language are computed, not stored', () {
      final now = DateTime(2026, 10, 21, 21, 30); // a Wednesday
      final ctx = TimeContext(
        now: now,
        sessionStartedAt: now.subtract(const Duration(minutes: 5)),
        lastInteractionAt: now.subtract(const Duration(days: 2)),
      );
      expect(ctx.clockLine, contains('Wednesday'));
      expect(ctx.clockLine, contains('21:30'));
      expect(ctx.daySegment, 'evening');
      expect(ctx.promptBlock(), contains('2 days'));
    });
  });

  group('3d stage', () {
    test('demo model clips are the verified RobotExpressive set', () {
      expect(demoAvatarConfig.modelSrc, demoModelSrc);
      // Every mapped clip must exist in the real GLB (verified by
      // parsing the bundled file's glTF header, 2026-10-21).
      for (final clip in demoAvatarConfig.animations.values) {
        expect(demoAnimations, contains(clip), reason: clip);
      }
    });

    test('director: speaking wins, then emotion, then idle, then null',
        () {
      const cfg = Avatar3DConfig(
        modelSrc: 'x.glb',
        animations: {'talk': 'Talk', 'joy': 'Happy', 'idle': 'Idle'},
      );
      expect(
          StageDirector.pickClip(cfg, emotion: 'joy', speaking: true),
          'Talk');
      expect(
          StageDirector.pickClip(cfg, emotion: 'joy', speaking: false),
          'Happy');
      expect(
          StageDirector.pickClip(cfg, emotion: 'grief', speaking: false),
          'Idle');
      const bare = Avatar3DConfig(modelSrc: 'x.glb', animations: {});
      expect(
          StageDirector.pickClip(bare, emotion: 'joy', speaking: false),
          isNull);
    });

    test('characters ship with no 3d model and parse one when given',
        () {
      expect(alpha.avatar3d, isNull);
      final withModel = CharacterDef.fromJson({
        'id': 'g', 'name': 'G', 'display_name': 'G', 'title': 'T',
        'roles': ['conversational'], 'core': 'c', 'personality': 'p',
        'speech_style': 's', 'interests': <String>[],
        'talkativeness': 0.5, 'volatility': 0.5,
        'baseline': {'pleasure': 0.0, 'arousal': 0.0, 'dominance': 0.0},
        'age_gated': false,
        'voice': {
          'display': 'V', 'eleven_labs_voice_id': 'i',
          'eleven_labs_voice_name': 'N', 'kokoro_voice': 'af_bella',
          'system_pitch': 1.0, 'system_rate': 0.5,
          'stability': 0.5, 'style': 0.3,
        },
        'avatar3d': {
          'model_src': 'assets/models/g.glb',
          'animations': {'idle': 'Idle'},
        },
      });
      expect(withModel.avatar3d?.hasModel, isTrue);
      expect(withModel.avatar3d?.animations['idle'], 'Idle');
    });
  });

  group('prosody', () {
    test('high arousal is faster and less stable than calm', () {
      final excited = Prosody.from(
          alpha.voice, const Pad(0.5, 0.9, 0.5));
      final calm = Prosody.from(alpha.voice, const Pad(0.2, -0.6, 0.2));
      expect(excited.rate, greaterThan(calm.rate));
      expect(excited.stability, lessThan(calm.stability));
      expect(excited.style, greaterThan(calm.style));
    });
  });
}
