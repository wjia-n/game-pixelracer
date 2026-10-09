import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Pixel Racer — chiptune / 16-bit arcade sounds.
/// All clips synthesized in code as WAV bytes and cached.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Clips are synthesized ONCE and cached; starting music never blocks the
///   UI thread after the first build.
/// - A [_musicGen] generation counter serializes track changes so overlapping
///   requests can never swallow a start or leave the player half-started.
/// - Lifecycle uses pause()/resume() so interruptions resume where they left
///   off instead of restarting or dying.
/// - An engine loop (separate player) follows race speed with playback rate.
/// - Every public method catches player errors; audio can never crash the app.
class RacerAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _engine = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  final Map<String, Uint8List> _cache = {};

  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  // Engine loop state.
  bool _engineOn = false;
  double _engineRate = 0.7;

  RacerAudio() {
    _music.setReleaseMode(ReleaseMode.loop);
    _engine.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.5 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    _engine.setVolume(sfxOn ? volume * 0.35 : 0.0);
    if (!musicOn) stopMusic();
    if (!sfxOn) stopEngine();
  }

  /// Pre-build clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
    _engineBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  /// Square-ish chip tone (lead). [freqEnd] slides the pitch.
  List<double> _chip(double freq, double secs,
      {double freqEnd = 0, double attack = 0.01, double duty = 0.5}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    double ph = 0;
    for (int i = 0; i < n; i++) {
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      ph += f / _rate;
      final sq = (ph % 1.0) < duty ? 1.0 : -1.0;
      out[i] = _env(i, n, attack: attack) * sq * 0.5;
    }
    return out;
  }

  List<double> _mix(List<double> a, List<double> b) {
    final n = max(a.length, b.length);
    final out = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      out[i] = (i < a.length ? a[i] : 0) + (i < b.length ? b[i] : 0);
    }
    return out;
  }

  List<double> _noise(double secs, {double cutoff = 4000}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0.0);
    double last = 0;
    final alpha = (cutoff / _rate).clamp(0.0, 1.0);
    for (int i = 0; i < n; i++) {
      last += alpha * ((_rand.nextDouble() * 2 - 1) - last);
      out[i] = last * _env(i, n, attack: 0.005);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  // ------------------------------------------------------- music synthesis
  Uint8List _menuBytes() => _clip('music_menu', () {
        // Cheerful chiptune loop: C major bouncy bass + melody, 8s.
        final bass = [130.81, 130.81, 196.0, 196.0, 174.61, 174.61, 196.0, 196.0];
        final lead = [
          523.25, 587.33, 659.25, 783.99,
          659.25, 587.33, 523.25, 392.0,
        ];
        final step = 0.5;
        var out = <double>[];
        for (int k = 0; k < bass.length; k++) {
          final b = _chip(bass[k], step, duty: 0.35);
          final l = _chip(lead[k], step, duty: 0.5);
          for (int i = 0; i < b.length; i++) {
            b[i] = b[i] * 0.5 + l[i] * 0.5;
          }
          out.addAll(b);
        }
        // Double it to 8s.
        return [...out, ...out];
      });

  Uint8List _gameBytes() => _clip('music_game', () {
        // Fast driving chiptune: E minor power bass + riff, 8s loop.
        final bass = [82.41, 82.41, 123.47, 82.41, 98.0, 98.0, 123.47, 146.83];
        final lead = [
          329.63, 392.0, 493.88, 392.0,
          329.63, 293.66, 246.94, 293.66,
        ];
        final step = 0.5;
        var out = <double>[];
        for (int k = 0; k < bass.length; k++) {
          final b = _chip(bass[k], step, duty: 0.35);
          final l = _chip(lead[k], step * 0.95, duty: 0.5);
          for (int i = 0; i < b.length; i++) {
            b[i] = b[i] * 0.55 + l[i] * 0.45;
          }
          out.addAll(b);
        }
        return [...out, ...out];
      });

  /// Engine loop: gritty low buzz, pitched up/down via playback rate.
  Uint8List _engineBytes() => _clip('engine', () {
        final n = (_rate * 0.5).round();
        final out = List<double>.filled(n, 0.0);
        double ph = 0;
        for (int i = 0; i < n; i++) {
          ph += 110.0 / _rate;
          final sq = (ph % 1.0) < 0.4 ? 1.0 : -1.0;
          final nz = _rand.nextDouble() * 2 - 1;
          out[i] = sq * 0.35 + nz * 0.12;
        }
        // Loop-friendly: fade the ends slightly.
        for (int i = 0; i < 200; i++) {
          final f = i / 200;
          out[i] *= f;
          out[n - 1 - i] *= f;
        }
        return out;
      });

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() =>
      _play(_clip('click', () => _chip(880, 0.06, freqEnd: 1200)));
  Future<void> invalid() => _play(_clip('invalid', () => _chip(160, 0.18)));
  Future<void> gameStart() => _play(_clip(
      'start', () => _mix(_chip(220, 0.5, freqEnd: 880), _noise(0.4))));
  Future<void> countBeep() => _play(_clip('count', () => _chip(440, 0.15)));
  Future<void> goBeep() => _play(_clip('go', () => _chip(880, 0.35)));
  Future<void> drift() => _play(_clip('drift', () => _noise(0.5)));
  Future<void> boost() => _play(
      _clip('boost', () => _mix(_chip(300, 0.4, freqEnd: 1500), _noise(0.35))));
  Future<void> crash() =>
      _play(_clip('crash', () => _noise(0.45, cutoff: 1500)));
  Future<void> lap() => _play(_clip(
      'lap', () => _mix(_chip(523.25, 0.12), _chip(783.99, 0.18))));
  Future<void> positionUp() =>
      _play(_clip('posup', () => _chip(600, 0.15, freqEnd: 900)));
  Future<void> win() => _play(_clip('win', () {
        final notes = [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5];
        var out = <double>[];
        for (final f in notes) {
          out.addAll(_chip(f, 0.16));
        }
        return out;
      }));
  Future<void> lose() => _play(_clip('lose', () {
        final notes = [392.0, 329.63, 261.63, 196.0];
        var out = <double>[];
        for (final f in notes) {
          out.addAll(_chip(f, 0.24));
        }
        return out;
      }));

  // ------------------------------------------------------------ engine loop
  Future<void> startEngine() async {
    if (_disposed || _engineOn || !sfxOn) return;
    _engineOn = true;
    try {
      await _engine.play(BytesSource(_engineBytes()));
      await _engine.setPlaybackRate(_engineRate);
    } catch (_) {
      _engineOn = false;
    }
  }

  /// Pitch the engine with speed: 0..1 → rate 0.7..1.6.
  Future<void> setEngineSpeed(double norm) async {
    if (!_engineOn || _disposed) return;
    final r = (0.7 + norm.clamp(0.0, 1.0) * 0.9).clamp(0.5, 1.8);
    if ((r - _engineRate).abs() < 0.05) return;
    _engineRate = r;
    try {
      await _engine.setPlaybackRate(r);
    } catch (_) {}
  }

  Future<void> stopEngine() async {
    if (!_engineOn) return;
    _engineOn = false;
    try {
      await _engine.stop();
    } catch (_) {}
  }

  // ----------------------------------------------------------------- music
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  /// App-scoped stop: cancels any pending start, then stops. Only for the
  /// user turning music OFF — never on screen navigation.
  Future<void> stopMusic() async {
    ++_musicGen;
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  Future<void> onAppPaused() async {
    if (_disposed) return;
    if (_currentTrack != null) {
      try {
        await _music.pause();
        _pausedByLifecycle = true;
      } catch (_) {}
    }
    if (_engineOn) {
      try {
        await _engine.pause();
      } catch (_) {}
    }
  }

  Future<void> onAppResumed() async {
    if (_disposed) return;
    if (_engineOn) {
      try {
        await _engine.resume();
      } catch (_) {
        _engineOn = false;
      }
    }
    if (!musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
      await _engine.dispose();
    } catch (_) {}
  }
}
