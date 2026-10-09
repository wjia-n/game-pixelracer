import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/pixel_themes.dart';

/// Persisted settings + stats for Pixel Racer. Survives app restarts.
///
/// Player names are stored as ONE JSON string (order-safe). Android's
/// SharedPreferences stores StringLists as an unordered StringSet, which
/// scrambles name order on restart — NEVER use a StringList for ordered
/// data. Legacy key [kNamesLegacy] is migrated once and removed.
class RacerSettings extends ChangeNotifier {
  static const _kMusic = 'pxr_music_on';
  static const _kSfx = 'pxr_sfx_on';
  static const _kVolume = 'pxr_volume';
  static const _kNamesLegacy = 'pxr_player_names'; // legacy unordered key
  /// Order-safe player-name storage: ONE JSON string via setString.
  /// (NEVER setStringList — Android backs it with an unordered StringSet.)
  static const _kNamesJson = 'pixelracer_player_names_json';
  /// Previous order-safe key (pre-exemplar) — migrated once, then dropped.
  static const _kNamesJsonLegacy = 'pxr_player_names_json';
  static const _kTheme = 'pxr_theme_id';
  static const _kCarStyle = 'pxr_car_style';
  static const _kTrackStyle = 'pxr_track_style';
  static const _kMode = 'pxr_mode'; // 0 race, 1 time trial, 2 endless
  static const _kDifficulty = 'pxr_difficulty'; // 0 easy, 1 medium, 2 hard
  static const _kAiLevel = 'pxr_ai_level'; // 0 chill, 1 racer, 2 ace
  static const _kHumans = 'pxr_humans'; // 1 or 2
  static const _kBots = 'pxr_bots'; // 0..3
  static const _kRaces = 'pxr_races';
  static const _kWins = 'pxr_wins';
  static const _kBestLap = 'pxr_best_lap_ms'; // 0 = none
  static const _kEndlessBest = 'pxr_endless_best_m';
  static const _kIsPro = 'pxr_is_pro';
  static const _kCustomPrefix = 'pxr_custom_';

  static const defaultNames = ['Speedy', 'Turbo', 'Blaze', 'Zippy'];
  static const aiLevelNames = ['Chill', 'Racer', 'Ace'];
  static const difficultyNames = ['Easy', 'Medium', 'Hard'];
  static const modeNames = ['Grand Prix', 'Time Trial', 'Endless Cruise'];

  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i] : s;
  }

  /// Decode persisted names; falls back to defaults on missing/corrupt data.
  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return List.of(defaultNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == 4) {
        return [for (int i = 0; i < 4; i++) _cleanName(i, d[i])];
      }
    } catch (_) {}
    return List.of(defaultNames);
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'arcade_classic';
  int carStyle = 0;
  int trackStyle = 0;
  int mode = 0;
  int difficulty = 1;
  int aiLevel = 1;
  int humans = 1;
  int bots = 3;
  int races = 0;
  int wins = 0;
  int bestLapMs = 0;
  int endlessBestM = 0;
  bool isPro = false;

  /// Custom theme colors (ARGB ints). Defaults mirror Arcade Classic.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'grass': 0xFF5FA04A,
    'grassDark': 0xFF4C8439,
    'track': 0xFF4A4A4A,
    'trackEdge': 0xFFE8E0C8,
    'startLine': 0xFFFFFFFF,
    'panel': 0xFF3A2E22,
    'panelEdge': 0xFF201712,
    'accent': 0xFFE0392B,
    'accentDark': 0xFFA32418,
    'text': 0xFFF5EFE0,
    'muted': 0xFFB9AE97,
    'pc0': 0xFFE0392B,
    'pc1': 0xFF2B6CE0,
    'pc2': 0xFF2BA84A,
    'pc3': 0xFFE0A52B,
  };

  PixelTheme get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    const names = ['One', 'Two', 'Three', 'Four'];
    return PixelTheme(
      id: 'custom',
      name: 'My Creation',
      pro: true,
      grass: c('grass'),
      grassDark: c('grassDark'),
      track: c('track'),
      trackEdge: c('trackEdge'),
      startLine: c('startLine'),
      panel: c('panel'),
      panelEdge: c('panelEdge'),
      accent: c('accent'),
      accentDark: c('accentDark'),
      text: c('text'),
      muted: c('muted'),
      danger: const Color(0xFFFF5544),
      carColors: [c('pc0'), c('pc1'), c('pc2'), c('pc3')],
      carColorNames: names,
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    // Player names: prefer the order-safe JSON key. One-time migration from
    // the previous JSON key, then the legacy StringList key (which may
    // already be scrambled on Android).
    final namesRaw =
        p.getString(_kNamesJson) ?? p.getString(_kNamesJsonLegacy);
    if (namesRaw != null) {
      playerNames = decodePlayerNames(namesRaw);
    } else {
      final legacy = p.getStringList(_kNamesLegacy);
      playerNames = (legacy != null && legacy.length == 4)
          ? [for (int i = 0; i < 4; i++) _cleanName(i, legacy[i])]
          : List.of(defaultNames);
    }
    themeId = p.getString(_kTheme) ?? 'arcade_classic';
    carStyle = (p.getInt(_kCarStyle) ?? 0).clamp(0, CarStyles.count - 1);
    trackStyle = (p.getInt(_kTrackStyle) ?? 0).clamp(0, TrackStyles.count - 1);
    mode = (p.getInt(_kMode) ?? 0).clamp(0, 2);
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 2);
    aiLevel = (p.getInt(_kAiLevel) ?? 1).clamp(0, 2);
    humans = (p.getInt(_kHumans) ?? 1).clamp(1, 2);
    bots = (p.getInt(_kBots) ?? 3).clamp(0, 3);
    races = p.getInt(_kRaces) ?? 0;
    wins = p.getInt(_kWins) ?? 0;
    bestLapMs = p.getInt(_kBestLap) ?? 0;
    endlessBestM = p.getInt(_kEndlessBest) ?? 0;
    isPro = p.getBool(_kIsPro) ?? false;
    for (final k in _defaultCustomColors.keys) {
      customColors[k] = p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kNamesJson, encodePlayerNames(playerNames));
    await p.remove(_kNamesJsonLegacy); // drop older JSON key for good
    await p.remove(_kNamesLegacy); // drop the legacy unordered key for good
    await p.setString(_kTheme, themeId);
    await p.setInt(_kCarStyle, carStyle);
    await p.setInt(_kTrackStyle, trackStyle);
    await p.setInt(_kMode, mode);
    await p.setInt(_kDifficulty, difficulty);
    await p.setInt(_kAiLevel, aiLevel);
    await p.setInt(_kHumans, humans);
    await p.setInt(_kBots, bots);
    await p.setInt(_kRaces, races);
    await p.setInt(_kWins, wins);
    await p.setInt(_kBestLap, bestLapMs);
    await p.setInt(_kEndlessBest, endlessBestM);
    await p.setBool(_kIsPro, isPro);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (PixelThemes.isProTheme(themeId)) {
      themeId = 'arcade_classic';
      changed = true;
    }
    if (CarStyles.isPro(carStyle)) {
      carStyle = 0;
      changed = true;
    }
    if (TrackStyles.isPro(trackStyle)) {
      trackStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (aiLevel > 1) {
      aiLevel = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return;
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(int index, String name) async {
    if (index < 0 || index > 3) return;
    final clean = name.trim();
    playerNames[index] = clean.isEmpty ? defaultNames[index] : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && PixelThemes.isProTheme(id)) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setCarStyle(int v) async {
    v = v.clamp(0, CarStyles.count - 1);
    if (!isPro && CarStyles.isPro(v)) return;
    carStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setTrackStyle(int v) async {
    v = v.clamp(0, TrackStyles.count - 1);
    if (!isPro && TrackStyles.isPro(v)) return;
    trackStyle = v;
    notifyListeners();
    await _save();
  }

  /// Full race setup from the menu.
  Future<void> setSetup({
    required int mode,
    required int difficulty,
    required int aiLevel,
    required int humans,
    required int bots,
  }) async {
    this.mode = mode.clamp(0, 2);
    this.difficulty = difficulty.clamp(0, 2);
    this.aiLevel = aiLevel.clamp(0, 2);
    this.humans = humans.clamp(1, 2);
    // Time Trial is a solo human mode; Endless allows 0 bots.
    this.bots = this.mode == 1
        ? 0
        : bots.clamp(0, 3);
    if (!isPro) {
      if (this.difficulty > 1) this.difficulty = 1;
      if (this.aiLevel > 1) this.aiLevel = 1;
    }
    // Grand Prix needs at least 2 racers total.
    if (this.mode == 0 && this.humans + this.bots < 2) {
      this.bots = 2 - this.humans;
    }
    notifyListeners();
    await _save();
  }

  /// Record a finished race. [humanWon] only meaningful in Grand Prix.
  /// [lapMs] is the player's best lap this race (0 = none recorded).
  /// [endlessM] is the endless distance in meters (0 = not endless).
  Future<void> recordRace({
    required bool humanWon,
    int lapMs = 0,
    int endlessM = 0,
  }) async {
    races++;
    if (humanWon) wins++;
    if (lapMs > 0 && (bestLapMs == 0 || lapMs < bestLapMs)) {
      bestLapMs = lapMs;
    }
    if (endlessM > endlessBestM) endlessBestM = endlessM;
    notifyListeners();
    await _save();
  }
}
