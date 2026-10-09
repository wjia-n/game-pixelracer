import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/pixel_themes.dart';
import 'name_field.dart';

/// Settings: audio toggles + volume, driver names, credits.
class SettingsScreen extends StatelessWidget {
  final RacerAudio audio;
  final RacerSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (_, _) {
        final theme = PixelThemes.byId(
          settings.themeId,
          custom: settings.customTheme,
        );
        return Scaffold(
          backgroundColor: theme.grassDark,
          appBar: AppBar(
            backgroundColor: theme.panel,
            foregroundColor: theme.text,
            title: Text('SETTINGS',
                style: PixelUi.display(22, theme: theme)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PixelUi.panel(
                  theme: theme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AUDIO', style: PixelUi.label(14, theme: theme)),
                      const SizedBox(height: 8),
                      _toggle(theme, 'Music', settings.musicOn, (v) {
                        settings.setMusic(v);
                        audio.configure(
                            musicOn: v,
                            sfxOn: settings.sfxOn,
                            volume: settings.volume);
                        if (v) {
                          audio.startMenuMusic();
                        } else {
                          audio.stopMusic();
                        }
                      }),
                      _toggle(theme, 'Sound effects', settings.sfxOn,
                          (v) {
                        settings.setSfx(v);
                        audio.configure(
                            musicOn: settings.musicOn,
                            sfxOn: v,
                            volume: settings.volume);
                        if (v) audio.click();
                      }),
                      const SizedBox(height: 8),
                      Text('Volume', style: PixelUi.body(15, theme: theme)),
                      Slider(
                        value: settings.volume,
                        activeColor: theme.accent,
                        inactiveColor: theme.muted,
                        onChanged: (v) {
                          settings.setVolume(v);
                          audio.configure(
                              musicOn: settings.musicOn,
                              sfxOn: settings.sfxOn,
                              volume: v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PixelUi.panel(
                  theme: theme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DRIVER NAMES',
                          style: PixelUi.label(14, theme: theme)),
                      const SizedBox(height: 8),
                      for (var i = 0; i < 4; i++)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                  width: 20,
                                  height: 20,
                                  color: theme.carColors[i]),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DriverNameField(
                                  key: ValueKey('settings_driver_$i'),
                                  theme: theme,
                                  index: i,
                                  initial: settings.playerNames[i],
                                  label:
                                      'Driver ${i + 1}${i < settings.humans ? '' : ' (AI)'}',
                                  onName: (v) =>
                                      settings.setPlayerName(i, v),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PixelUi.panel(
                  theme: theme,
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/wajiha_logo.png',
                            width: 34,
                            height: 34,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const SizedBox(width: 34),
                          ),
                          const SizedBox(width: 10),
                          Text('Credits: WAJIHA',
                              style: PixelUi.label(14, theme: theme)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pixel Racer v1.0 — a tiny arcade racer by Wajiha. All art and audio generated in-code; no engines were harmed.',
                        textAlign: TextAlign.center,
                        style: PixelUi.body(12,
                            theme: theme, color: theme.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _toggle(PixelTheme theme, String label, bool value,
      ValueChanged<bool> onChange) {
    return Row(
      children: [
        Expanded(child: Text(label, style: PixelUi.body(15, theme: theme))),
        Switch(
          value: value,
          activeThumbColor: theme.accent,
          onChanged: onChange,
        ),
      ],
    );
  }
}
