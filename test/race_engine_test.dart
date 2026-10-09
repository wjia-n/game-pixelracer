import 'package:flutter_test/flutter_test.dart';
import 'package:pixelracer/engine/race_engine.dart';
import 'package:pixelracer/services/settings_service.dart';

void main() {
  test('track builds the requested number of samples', () {
    final e = RaceEngine();
    e.startRace(
      configs: const [
        RacerConfig(name: 'A', isBot: false, carColorIndex: 0, carStyle: 0),
        RacerConfig(
            name: 'B', isBot: true, aiLevel: 0, carColorIndex: 1, carStyle: 1),
      ],
      mode: RaceMode.grandPrix,
      trackStyle: 3,
      difficulty: 0,
      seed: 42,
    );
    expect(e.trackPoints.length, RaceEngine.trackSamples);
    expect(e.phase, RacePhase.countdown);
    expect(e.racers.length, 2);
    e.dispose();
  });

  test('different seeds produce different tracks', () {
    final a = RaceEngine();
    final b = RaceEngine();
    const cfgs = [
      RacerConfig(name: 'A', isBot: false, carColorIndex: 0, carStyle: 0),
    ];
    a.startRace(
        configs: cfgs, mode: RaceMode.timeTrial, trackStyle: 0, difficulty: 1, seed: 1);
    b.startRace(
        configs: cfgs, mode: RaceMode.timeTrial, trackStyle: 0, difficulty: 1, seed: 2);
    expect(a.trackPoints[10], isNot(equals(b.trackPoints[10])));
    a.dispose();
    b.dispose();
  });

  test('pause and resume keep a live race moving', () {
    final e = RaceEngine();
    e.startRace(
      configs: const [
        RacerConfig(name: 'A', isBot: false, carColorIndex: 0, carStyle: 0),
      ],
      mode: RaceMode.timeTrial,
      trackStyle: 0,
      difficulty: 1,
      seed: 7,
    );
    e.pause();
    expect(e.phase, RacePhase.paused);
    e.resume();
    expect(
        e.phase == RacePhase.countdown || e.phase == RacePhase.racing, true);
    e.dispose();
  });

  test('quitToIdle clears the race', () {
    final e = RaceEngine();
    e.startRace(
      configs: const [
        RacerConfig(name: 'A', isBot: false, carColorIndex: 0, carStyle: 0),
      ],
      mode: RaceMode.endless,
      trackStyle: 0,
      difficulty: 1,
      seed: 7,
    );
    e.quitToIdle();
    expect(e.phase, RacePhase.idle);
    expect(e.racers, isEmpty);
    e.dispose();
  });

  test('player names survive a JSON round-trip in order', () {
    const names = ['Zed', 'Amy', 'Bob', 'Cara'];
    final raw = RacerSettings.encodePlayerNames(names);
    expect(RacerSettings.decodePlayerNames(raw), names);
    // Corrupt data falls back to defaults, never crashes.
    expect(RacerSettings.decodePlayerNames('nope'),
        RacerSettings.defaultNames);
    expect(RacerSettings.decodePlayerNames(null), RacerSettings.defaultNames);
  });
}
