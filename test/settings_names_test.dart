import 'package:flutter_test/flutter_test.dart';
import 'package:pixelracer/engine/race_engine.dart';
import 'package:pixelracer/services/settings_service.dart';

/// Regression tests for the player-name persistence bug (2026-10-09):
///
/// Player names were stored with SharedPreferences.setStringList, which on
/// Android is backed by an UNORDERED StringSet — so after an app restart the
/// four names came back in arbitrary order and renames appeared "not saved".
/// Names are now stored as one order-preserving JSON string under the key
/// `pixelracer_player_names_json` (via setString), saved on every keystroke
/// and committed on focus loss. These tests cover the encode/decode
/// round-trip plus the engine reload path, without needing platform channels.
void main() {
  test('names survive an encode/decode round-trip in exact slot order', () {
    const names = ['Wajiha', 'Zara', 'Ali', 'Bot Bob'];
    final decoded = RacerSettings.decodePlayerNames(
      RacerSettings.encodePlayerNames(names),
    );
    expect(decoded, names);
    // Slot order is what matters: each index must map to the same driver.
    for (int i = 0; i < 4; i++) {
      expect(decoded[i], names[i]);
    }
  });

  test('decode falls back to defaults on missing or corrupt data', () {
    expect(
      RacerSettings.decodePlayerNames(null),
      RacerSettings.defaultNames,
    );
    expect(
      RacerSettings.decodePlayerNames('definitely not json'),
      RacerSettings.defaultNames,
    );
    expect(
      RacerSettings.decodePlayerNames('["only","two"]'),
      RacerSettings.defaultNames,
    );
    expect(
      RacerSettings.decodePlayerNames('{"a":1}'),
      RacerSettings.defaultNames,
    );
  });

  test('blank entries fall back to that slot\'s default name', () {
    final decoded =
        RacerSettings.decodePlayerNames('["Wajiha","","  ","Zippy"]');
    expect(decoded, ['Wajiha', 'Turbo', 'Blaze', 'Zippy']);
  });

  test('engine rebuilt after "restart" shows the persisted names', () {
    // Simulate: user renamed slot 0, app restarted, menu + engine rebuilt
    // from the persisted value.
    const renamed = ['Wajiha', 'Turbo', 'Blaze', 'Zippy'];
    final persisted = RacerSettings.decodePlayerNames(
      RacerSettings.encodePlayerNames(renamed),
    );
    final engine = RaceEngine();
    engine.startRace(
      configs: [
        for (int i = 0; i < persisted.length; i++)
          RacerConfig(
            name: persisted[i],
            isBot: i == 3,
            aiLevel: 1,
            carColorIndex: i,
            carStyle: 0,
          ),
      ],
      mode: RaceMode.grandPrix,
      trackStyle: 0,
      difficulty: 1,
      seed: 7,
    );
    addTearDown(engine.dispose);
    expect(engine.racers[0].name, 'Wajiha');
    expect(engine.racers[1].name, 'Turbo');
    expect(engine.racers[2].name, 'Blaze');
    expect(engine.racers[3].name, 'Zippy');
  });
}
