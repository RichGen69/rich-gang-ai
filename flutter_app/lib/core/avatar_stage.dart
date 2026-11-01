import 'character.dart';

/// The Stage Director: decides what a 3D avatar is DOING, from the
/// same real state everything else in this app uses — the focused
/// agent's derived emotion (affect_engine) and whether it is
/// currently speaking (voice_engine call in flight).
///
/// Selection order (pure, unit-tested):
///  1. speaking → the model's "talk" slot,
///  2. else the slot named by the agent's current emotion,
///  3. else the "idle" slot,
///  4. else null — no forced animation; model-viewer plays the
///     model's own default. Returning null is the honest outcome
///     for a model whose clips we know nothing about.
class StageDirector {
  static String? pickClip(
    Avatar3DConfig config, {
    required String emotion,
    required bool speaking,
  }) {
    final a = config.animations;
    if (speaking && a['talk'] != null) return a['talk'];
    if (a[emotion] != null) return a[emotion];
    return a['idle'];
  }
}

/// The stage's DEMO model — present to prove the whole 3D pipeline
/// (loading, camera, emotion-driven animation, gestures) with a
/// real, inspectable asset, and labelled as a demo everywhere it
/// appears. It is NOT any of Richard's characters and the UI never
/// presents it as one.
///
/// Asset: assets/models/stage_demo_robot.glb — "RobotExpressive"
/// from the three.js examples (pinned r160), downloaded
/// 2026-10-21 and verified by parsing its glTF header in this
/// workspace: clips are exactly [demoAnimations] below.
const demoModelSrc = 'assets/models/stage_demo_robot.glb';

const demoAnimations = <String>[
  'Dance', 'Death', 'Idle', 'Jump', 'No', 'Punch', 'Running',
  'Sitting', 'Standing', 'ThumbsUp', 'Walking', 'WalkJump', 'Wave',
  'Yes',
];

/// Demo slot mapping — a design choice for the DEMO robot only
/// (its clips are known, above). Character models bring their own
/// mapping in characters.json / the Stage's per-character override.
const demoAvatarConfig = Avatar3DConfig(
  modelSrc: demoModelSrc,
  animations: {
    'idle': 'Idle',
    'talk': 'Wave',
    'joy': 'Dance',
    'excitement': 'Dance',
    'amusement': 'Jump',
    'surprise': 'Jump',
    'pride': 'ThumbsUp',
    'affection': 'ThumbsUp',
    'calm': 'Idle',
    'contentment': 'Idle',
    'curiosity': 'Standing',
    'anger': 'Punch',
    'frustration': 'No',
    'disgust': 'No',
    'anxiety': 'Sitting',
    'sadness': 'Sitting',
    'boredom': 'Sitting',
    'agree': 'Yes',
    'disagree': 'No',
    'greet': 'Wave',
  },
);

/// One-tap gestures on the Stage, resolved against whichever model
/// is loaded. Labels are what Richard taps; clip names come from
/// the model's config (demo values shown in the map below).
const stageGestures = <String, String>{
  'Greet': 'greet',
  'Agree': 'agree',
  'Disagree': 'disagree',
  'Celebrate': 'joy',
  'Proud': 'pride',
};
