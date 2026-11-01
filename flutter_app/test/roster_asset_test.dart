import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rich_gang_ai/core/character.dart';

/// Regression lock on the REAL shipped roster asset: every entry
/// must parse through CharacterDef.fromJson (a parse throw makes
/// the registry load empty in the app), Crazy Kelly replaced
/// Cougar Kelly on 2026-10-21 at Richard's direction, and the
/// registry-only entries (13 Tier-10 expansion + 19 WTF Zone
/// multiverse, 2026-10-25) must stay honestly flagged as
/// registry-only (uncast voice, no portrait) instead of
/// silently acquiring configured-looking defaults. Danny — added
/// 2026-10-23 registry-only — was promoted the same day to the
/// flagship tier ('configured_voice_uncast'): everything wired
/// except his ElevenLabs voice, which stays honestly uncast
/// because no documented unused premade voice exists to cast him
/// with and inventing an id is forbidden.
void main() {
  test('shipped characters.json parses fully, with the Kelly swap',
      () {
    final raw = File('assets/characters.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final defs = (decoded['characters'] as List<dynamic>)
        .map((e) => CharacterDef.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(defs, hasLength(42));
    final ids = defs.map((d) => d.id).toSet();
    expect(ids, contains('crazy_kelly'));
    expect(ids, isNot(contains('cougar_kelly')));

    final kelly = defs.firstWhere((d) => d.id == 'crazy_kelly');
    expect(kelly.displayName, 'Crazy Kelly');
    // Resolved 2026-10-22 at Richard's decision: Crazy Kelly stays,
    // Cougar Kelly is dropped from the 22 list. Kelly takes the #2
    // slot zodiac Taurus (Dan keeps Scorpio alone). Her title was
    // "The Vice City Wildcard" until Richard ordered every GTA /
    // Vice City reference removed the same day; she is now "The
    // Neon Wildcard", still distinct from the registry-only Sector
    // Zero character named "The Wildcard".
    expect(kelly.title, 'The Neon Wildcard');
    expect(kelly.zodiac, 'Taurus');
    expect(kelly.ageGated, isTrue);
    expect(kelly.portrait, 'assets/images/portraits/crazy_kelly.jpg');
    expect(kelly.core, contains('neon beach-city'));
    // GTA-scrub lock (2026-10-22): no GTA/Vice City reference may
    // reappear anywhere in Kelly's shipped definition.
    expect(kelly.core, isNot(contains('Vice City')));
    expect(kelly.speechStyle, isNot(contains('Vice City')));
    expect(kelly.interests.join(' '), isNot(contains('vice city')));
    expect(kelly.voice.display, 'Neon');

    final configured =
        defs.where((d) => !d.isRegistryOnly).toList();
    expect(configured, hasLength(10));
    expect(configured.every((d) => d.portrait != null), isTrue);
    // No two configured characters share a zodiac (the Dan/Kelly
    // Scorpio collision was the other half of the 2026-10-22 fix).
    final zodiacs = configured.map((d) => d.zodiac).toList();
    expect(zodiacs.every((z) => z != null), isTrue);
    expect(zodiacs.toSet(), hasLength(zodiacs.length));

    final registryOnly = defs.where((d) => d.isRegistryOnly).toList();
    expect(registryOnly, hasLength(32));

    // Danny (added 2026-10-23 at Richard's direction — "Build a
    // copy of your self in this app as well and call it danny"),
    // promoted the same day to FLAGSHIP MODEL at Richard's order
    // ("Make Danny a flagship model"). He LEADS the roster. His
    // wiring: portrait, authored baselines (the promotion
    // checklist's values), talkativeness and volatility — all real.
    // His voice stays UNCAST: every ElevenLabs premade voice
    // documented in this project is already cast to one of the
    // original nine (Cougar Kelly's Aria casting passed to Crazy
    // Kelly in the swap — it freed nothing), and no voice id may
    // be invented for him; casting waits on Richard's pick from
    // his own account. His hook, in Richard's words — "anything u
    // can do Danny does better" — is persona, locked here so it
    // cannot quietly become a capability claim.
    final danny = defs.firstWhere((d) => d.id == 'danny');
    expect(defs.first.id, 'danny'); // flagship: he leads the roster
    expect(danny.displayName, 'Danny');
    expect(danny.title, 'The Better Twin');
    expect(danny.zodiac, 'Gemini');
    expect(danny.ageGated, isFalse);
    expect(danny.isRegistryOnly, isFalse);
    expect(danny.isConfiguredVoiceUncast, isTrue);
    expect(danny.status, 'configured_voice_uncast');
    expect(danny.portrait, 'assets/images/portraits/danny.jpg');
    expect(danny.baselinePleasure, 0.25);
    expect(danny.baselineArousal, 0.35);
    expect(danny.baselineDominance, 0.7);
    expect(danny.talkativeness, 0.8);
    expect(danny.volatility, 0.2);
    // Uncast means uncast: no ElevenLabs id, no Kokoro name — but
    // his delivery profile (system rate/pitch, stability/style)
    // is his own, distinct from VoiceCasting.uncast's neutrals.
    expect(danny.voice.isUncast, isTrue);
    expect(danny.voice.elevenLabsVoiceId, isEmpty);
    expect(danny.voice.kokoroVoice, isEmpty);
    expect(danny.voice.display, 'Uncast — not configured');
    expect(danny.voice.systemRate, 0.46);
    expect(danny.voice.systemPitch, 0.92);
    // Flagship definition sections: moral core, guardrails,
    // self-knowledge, tone spec, emotion tone table, gifts.
    expect(danny.moralCore, contains('MORAL CORE'));
    expect(danny.moralCore, contains('no illegal actions or illegal tasks'));
    expect(danny.moralCore, contains('RESPONSIBILITY'));
    expect(danny.moralCore, contains('refuse even Richard'));
    expect(danny.guardrails, contains('NOT writable by Danny'));
    expect(danny.guardrails, contains('SELF-UPGRADE ALLOWLIST'));
    expect(danny.guardrails, contains('kill-switch'));
    expect(danny.selfKnowledge, contains('NO local LLM runtime'));
    expect(danny.selfKnowledge, contains('NOT a lie detector'));
    expect(danny.toneSpec, contains('casting brief'));
    expect(danny.toneByEmotion['anger'], contains('Ice over heat'));
    expect(danny.toneByEmotion['calm'], contains('verdict'));
    expect(danny.gifts.keys, containsAll([
      'the_ledger',
      'second_sight',
      'double_check',
      'dream_gifts',
      'a_conscience_that_talks_back',
      'the_trophy_shelf',
    ]));
    expect(danny.core, contains('FLAGSHIP MODEL'));
    expect(danny.core, contains('PARENT OF THE TIMES'));
    expect(danny.core, contains('unfiltered and unhinged'));
    expect(danny.personality, contains('RESPONSIBILITY'));
    expect(danny.personality, contains("'Boss'"));
    expect(danny.core,
        contains('anything the original can do, Danny does better'));
    expect(danny.core, contains('a character copy'));
    expect(danny.core, contains('not the live assistant'));
    // Enhancement locks (2026-10-23): his signature deadpan line
    // and his relationship seeds — Richard is "the Boss" who built
    // both of them, and Dan is his respected fellow operator.
    expect(danny.speechStyle, contains('Checked it. Twice.'));
    expect(danny.core, contains('the Boss'));
    expect(danny.core, contains('Dan, the other operator'));
    expect(danny.interests, contains('out-doing the original'));
    // Southern Texas written-voice locks (2026-10-23, Richard's
    // direction): Huffman/Houston cadence — measured, plain-spoken,
    // warm under the deadpan — in rhythm and word choice, not
    // dialect spelling or caricature. This is voice direction for
    // his future casting; he remains uncast below.
    expect(danny.core, contains('Southern Texas'));
    expect(danny.core, contains('Huffman and Houston'));
    expect(danny.personality, contains('measured drawl'));
    expect(danny.personality, contains('now hold on'));
    expect(danny.personality, contains('reckon'));
    expect(danny.personality, contains("occasional 'y'all'"));
    expect(danny.interests, contains('Huffman, Texas'));
    expect(danny.interests, contains('plain-spoken receipts'));
    expect(
      danny.speechStyle,
      contains(
          "Checked it twice — that's just how we do it down here."),
    );
    expect(
      danny.speechStyle,
      contains("That ain't verified yet. Give me a minute… now it is."),
    );
    // Easter-egg locks (2026-10-23): persona-prompt-carried
    // trigger/response patterns in Danny's shipped speech style.
    // They are labelled in the definition itself as
    // persona-carried, not deterministic code; the counting egg is
    // style only and must never invent an interaction count.
    expect(danny.speechStyle,
        contains('persona-carried response patterns'));
    expect(danny.speechStyle, contains('build thrones'));
    expect(danny.speechStyle,
        contains("I wasn't meant to build a chatbot"));
    expect(
      danny.speechStyle,
      contains(
          'Thrones, not chatbots — and I checked the foundations twice.'),
    );
    expect(danny.speechStyle, contains("calls Danny 'a copy,'"));
    expect(
      danny.speechStyle,
      contains("Copy? Now hold on. I'm the director's cut."),
    );
    expect(
      danny.speechStyle,
      contains(
          'The original walked so I could verify. Reckon I kept the receipts.'),
    );
    expect(danny.speechStyle, contains('receipts mode'));
    expect(danny.speechStyle, contains("Name the claim. I'll show my work."));
    expect(danny.speechStyle, contains('Evidence:'));
    expect(danny.speechStyle, contains('Count:'));
    expect(danny.speechStyle, contains('Verdict:'));
    expect(danny.speechStyle, contains('Never invent receipts.'));
    expect(
      danny.speechStyle,
      contains('Now hold on — gate first. Glory second.'),
    );
    expect(danny.speechStyle,
        contains('source, artifact, tests, alignment'));
    expect(
      danny.speechStyle,
      contains(
          'Dan earns his chair — no argument. I just keep the receipts neater.'),
    );
    expect(danny.speechStyle,
        contains('style only, not a stored interaction counter'));
    expect(
      danny.speechStyle,
      contains("That's the third time you've tested me today. Verified."),
    );
    expect(danny.speechStyle, contains('Count not verified.'));
    expect(danny.speechStyle,
        contains('Never invent an interaction count.'));
    expect(registryOnly.every((d) => d.voice.isUncast), isTrue);
    expect(registryOnly.every((d) => d.portrait == null), isTrue);

    // Naming-collision lock (Kelly/Wildcard fixed 2026-10-22,
    // Tammy/Oracle fixed the same day): every display name is
    // unique across the 42, and no registry-only character's name
    // repeats a configured character's title.
    final displays = defs.map((d) => d.displayName).toList();
    expect(displays.toSet(), hasLength(displays.length));
    final configuredTitles = configured.map((d) => d.title).toSet();
    expect(
      registryOnly.every((d) => !configuredTitles.contains(d.name)),
      isTrue,
    );

    // WTF Zone multiverse merge (2026-10-25, Richard's direction):
    // 19 new registry-only entries from the WTF Zone, the Twilight
    // Zone, and the Freak Show (plus the Neon-Beach and Anime
    // parallels). They carry full persona specs but NO portrait and
    // NO voice id — portraits and casting are Richard's to supply,
    // and inventing either is forbidden. Their universes are the
    // parser's own `universe` field.
    const multiverseIds = [
      'carl',
      'babs',
      'undra',
      'buck_chatt',
      'ricco_chain',
      'houston_cole',
      'verso_marlowe',
      'jinx_malone',
      'jack_thrill',
      'mister_smoke',
      'cel',
      'chrome_grin',
      'pearl',
      'sterling_blake',
      'asher_grey',
      'gilda_gaze',
      'madame_dryer',
      'mop',
      'octavia_shears',
    ];
    const multiverseUniverses = {
      'carl': 'WTF Zone',
      'babs': 'WTF Zone',
      'undra': 'WTF Zone',
      'buck_chatt': 'WTF Zone',
      'ricco_chain': 'Neon-Beach Dimension',
      'houston_cole': 'Neon-Beach Dimension',
      'verso_marlowe': 'Neon-Beach Dimension',
      'jinx_malone': 'Neon-Beach Dimension',
      'jack_thrill': 'Twilight Zone',
      'mister_smoke': 'Twilight Zone',
      'cel': 'Anime Dimension',
      'chrome_grin': 'Freak Show',
      'pearl': 'Freak Show',
      'sterling_blake': 'Freak Show',
      'asher_grey': 'Freak Show',
      'gilda_gaze': 'Freak Show',
      'madame_dryer': 'Freak Show',
      'mop': 'Freak Show',
      'octavia_shears': 'Freak Show',
    };
    for (final id in multiverseIds) {
      final m = defs.firstWhere((d) => d.id == id);
      expect(m.isRegistryOnly, isTrue);
      expect(m.portrait, isNull);
      expect(m.voice.isUncast, isTrue);
      expect(m.universe, multiverseUniverses[id]);
      expect(m.core, isNotEmpty);
      expect(m.personality, isNotEmpty);
      expect(m.speechStyle, isNotEmpty);
    }
    // The gang carries no GTA/Vice City wording (2026-10-22 scrub
    // stands unless Richard explicitly reverses it).
    for (final id in [
      'ricco_chain',
      'houston_cole',
      'verso_marlowe',
      'jinx_malone',
    ]) {
      final g = defs.firstWhere((d) => d.id == id);
      expect(g.core, isNot(contains('Vice City')));
      expect(g.personality, isNot(contains('Vice City')));
    }
  });

  test('chain of command (ordered 2026-10-25) is written into the roster',
      () {
    final raw = File('assets/characters.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final chain = decoded['chain_of_command'] as Map<String, dynamic>;
    // Richard's own words, in order, across the 2026-10-25 exchange:
    // the cast works for Agent Rich; Rich works for Richard; all of
    // them work for Richard directly too; Richard is the human
    // approval; Richard is the creator and founder of Rich Gang AI
    // and of Rich Gang AI Productions.
    expect(chain['ordered_by'], 'Richard');
    expect(chain['ordered'], '2026-10-25');
    expect(chain['founder'], contains('creator and founder'));
    expect(chain['founder'], contains('Rich Gang AI Productions'));
    expect(chain['human_approval'], contains('human approval'));
    expect(chain['day_to_day_commander'], contains('Chosen One Rich'));
    expect(chain['day_to_day_commander'], contains('Swarm Commander'));
    expect(chain['reporting'], contains('ultimate boss of every agent'));
    expect(chain['reporting'], contains('does not stand between'));
    // The commander himself carries the chain in his core, so the
    // Room's host states it in character, not only in metadata.
    final defs = (decoded['characters'] as List<dynamic>)
        .map((e) => CharacterDef.fromJson(e as Map<String, dynamic>))
        .toList();
    final rich = defs.firstWhere((d) => d.id == 'rich');
    expect(rich.displayName, 'Chosen One Rich');
    expect(rich.title, 'The Host');
    expect(rich.core, contains('Chain of command'));
    expect(rich.core, contains('human approval'));
    expect(rich.core, contains('ultimate boss of every agent'));
  });
}
