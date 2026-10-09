import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';
import 'theme/pixel_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = RacerSettings();
  await settings.load();
  final audio = RacerAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(PixelRacerApp(settings: settings, audio: audio));
}

class PixelRacerApp extends StatefulWidget {
  final RacerSettings settings;
  final RacerAudio audio;
  const PixelRacerApp(
      {super.key, required this.settings, required this.audio});

  @override
  State<PixelRacerApp> createState() => _PixelRacerAppState();
}

class _PixelRacerAppState extends State<PixelRacerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; race screens additionally freeze their engines.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) {
        final theme = PixelThemes.byId(
          widget.settings.themeId,
          custom: widget.settings.customTheme,
        );
        return MaterialApp(
          title: 'Pixel Racer',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: theme.grassDark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: theme.accent,
              brightness: Brightness.dark,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: theme.panel,
              foregroundColor: theme.text,
            ),
            sliderTheme: SliderThemeData(
              activeTrackColor: theme.accent,
              thumbColor: theme.accent,
            ),
          ),
          home: SplashScreen(
              audio: widget.audio, settings: widget.settings),
        );
      },
    );
  }
}
