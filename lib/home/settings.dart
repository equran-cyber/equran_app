import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:equran/backend/library.dart'
    show BookmarkDB, FavouritesDB, SettingsDB;
import 'package:equran/backend/backup_service.dart';
import 'package:equran/utils/app_theme.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:equran/utils/library.dart';
import 'package:equran/widgets/library.dart'
    show FontSlider, PlayBackSlider, SettingsSwitch;
import 'package:flutter/material.dart';
import 'package:quran/quran.dart' show Translation;
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<String> getVersion() async {
    final info = await PackageInfo.fromPlatform();
    return "${info.version}+${info.buildNumber}";
  }

  @override
  Widget build(BuildContext context) {
    final bool cardViewEnabled = SettingsDB().get(
      "viewMode",
      defaultValue: true,
    );
    final bool translationEnabled = SettingsDB().get(
      "enableTranslation",
      defaultValue: true,
    );
    final bool showTranslationControls =
        cardViewEnabled && translationEnabled;

    return Material(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: <Widget>[
          _buildSettingsGroup(
            context: context,
            title: "General",
            subtitle: "App behavior and history",
            icon: Icons.tune_rounded,
            initiallyExpanded: true,
            children: const <Widget>[
              SettingsSwitch(
                title: "Vibration",
                subtitle: "Enable haptic feedback when navigating.",
                settingsKey: "vibration",
              ),
              SettingsSwitch(
                title: "Show reading history",
                settingsKey: "showLastRead",
                subtitle: "Shows you up to 7 last read Surahs.",
              ),
            ],
          ),
          _buildSettingsGroup(
            context: context,
            title: "Reading",
            subtitle: "Quran display and translation",
            icon: Icons.menu_book_rounded,
            initiallyExpanded: true,
            children: <Widget>[
              SettingsSwitch(
                title: "Card View",
                subtitle: "Displays each verse separately, or all in one page.",
                settingsKey: "viewMode",
                onChanged: (_) => setState(() {}),
              ),
              if (cardViewEnabled)
                SettingsSwitch(
                  title: "Enable Translation",
                  subtitle: "Enables translation for each verse.",
                  settingsKey: "enableTranslation",
                  onChanged: (_) => setState(() {}),
                ),
              if (showTranslationControls) _buildTranslationTile(context),
              FontSlider(showTranslationControls: showTranslationControls),
            ],
          ),
          _buildSettingsGroup(
            context: context,
            title: "Audio",
            subtitle: "Reciter and playback",
            icon: Icons.graphic_eq_rounded,
            children: <Widget>[
              _buildReciterTile(context),
              const PlayBackSlider(),
            ],
          ),
          _buildSettingsGroup(
            context: context,
            title: "Appearance",
            subtitle: "Theme, color, and display mode",
            icon: Icons.palette_outlined,
            children: <Widget>[
              _buildThemeModeTile(context),
              _buildThemeColorTile(context),
            ],
          ),
          _buildSettingsGroup(
            context: context,
            title: "Data",
            subtitle: "Backup, restore, or clear saved local data",
            icon: Icons.storage_rounded,
            children: <Widget>[
              _buildBackupDataTile(context),
              _buildRestoreDataTile(context),
              _buildClearReadingHistoryTile(context),
              _buildClearFavouritesTile(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(subtitle),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildTranslationTile(BuildContext context) {
    return ListTile(
      title: const Text("Translation"),
      subtitle: Text(_selectedTranslationName()),
      onTap: () {
        List<Translation> items = Translation.values;
        int selected = SettingsDB().get("translation", defaultValue: 0);
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, dialogSetState) {
                return AlertDialog(
                  title: const Text("Select Language"),
                  content: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: items.asMap().entries.map((entry) {
                        int index = entry.key;
                        return RadioListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadii.medium,
                            ),
                          ),
                          title: Text(entry.value.name),
                          value: index,
                          groupValue: selected,
                          onChanged: (int? value) {
                            SettingsDB().put("translation", value);
                            if (mounted) {
                              setState(() {});
                            }
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildReciterTile(BuildContext context) {
    return ListTile(
      title: const Text("Reciter"),
      subtitle: Text(_selectedReciterName()),
      onTap: () {
        final List<AppReciter> items = AppReciter.values.toList()
          ..sort(
            (a, b) => a.englishName.toLowerCase().compareTo(
              b.englishName.toLowerCase(),
            ),
          );
        final selected = SettingsDB().get("reciter", defaultValue: "1");
        final selectedReciter = AppReciter.fromCode(selected);
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, dialogSetState) {
                return AlertDialog(
                  title: const Text("Select Reciter"),
                  content: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: items.asMap().entries.map((entry) {
                        return RadioListTile<AppReciter>(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadii.medium,
                            ),
                          ),
                          title: Text(entry.value.englishName),
                          value: entry.value,
                          groupValue: selectedReciter,
                          onChanged: (value) {
                            if (value == null) return;
                            SettingsDB().put("reciter", value.code);
                            if (mounted) {
                              setState(() {});
                            }
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildThemeColorTile(BuildContext context) {
    return ListTile(
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Choose a Color'),
              icon: const Icon(Icons.format_paint_rounded),
              content: Wrap(
                runSpacing: 10,
                spacing: 10,
                children: List.generate(Colors.primaries.length, (index) {
                  final color = Colors.primaries[index];
                  return InkWell(
                    onTap: () {
                      SettingsDB().put("color", index);
                      if (mounted) {
                        setState(() {});
                      }

                      AdaptiveTheme.of(context).setTheme(
                        light: AppTheme.buildLightTheme(color),
                        dark: AppTheme.buildDarkTheme(color),
                      );
                    },
                    child: CircleAvatar(backgroundColor: color, radius: 18),
                  );
                }),
              ),
            );
          },
        );
      },
      title: const Text("Color scheme"),
      subtitle: Text(_selectedThemeName()),
    );
  }

  Widget _buildClearReadingHistoryTile(BuildContext context) {
    return ListTile(
      title: const Text("Clear reading history"),
      subtitle: const Text("Removes all your reading history."),
      onTap: () => _showClearDataDialog(
        context: context,
        title: "Clear reading history",
        message:
            "WARNING: Are you sure you want to clear your reading history?",
        onConfirm: () async => BookmarkDB().clear(),
      ),
    );
  }

  Widget _buildBackupDataTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.backup_outlined),
      title: const Text("Backup data"),
      subtitle: const Text(
        "Exports favourites, reading history, reciter, text sizes, and all settings.",
      ),
      onTap: () async {
        try {
          final String? outputPath = await BackupService.exportBackupFile();
          if (!context.mounted) return;
          _showMessage(
            context,
            outputPath == null
                ? 'Backup file ready to share.'
                : 'Backup saved to $outputPath',
          );
        } on AppBackupException catch (error) {
          if (error.message != 'Backup cancelled.') {
            _showMessage(context, error.message);
          }
        } catch (_) {
          _showMessage(context, 'Unable to create the backup file.');
        }
      },
    );
  }

  Widget _buildRestoreDataTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.restore_page_outlined),
      title: const Text("Restore data"),
      subtitle: const Text(
        "Restores favourites, reading history, reciter, text sizes, and saved settings from a backup file.",
      ),
      onTap: () async {
        final bool shouldRestore = await _showRestoreConfirmation(context);
        if (!shouldRestore || !context.mounted) return;

        try {
          final BackupRestoreResult result =
              await BackupService.restoreFromPickedFile();
          if (!context.mounted) return;
          await _applyRestoredTheme(context);
          setState(() {});
          _showMessage(
            context,
            'Restored ${result.favouritesCount} favourites, ${result.readingHistoryCount} history entries, and ${result.settingsCount} settings.',
          );
        } on AppBackupException catch (error) {
          if (error.message != 'Restore cancelled.' && context.mounted) {
            _showMessage(context, error.message);
          }
        } catch (_) {
          if (context.mounted) {
            _showMessage(context, 'Unable to restore the selected backup.');
          }
        }
      },
    );
  }

  Widget _buildClearFavouritesTile(BuildContext context) {
    return ListTile(
      title: const Text("Clear Favourites"),
      subtitle: const Text("Removes all verses you have liked."),
      onTap: () => _showClearDataDialog(
        context: context,
        title: "Clear Favourites",
        message: "WARNING: Are you sure you want to clear favourites?",
        onConfirm: () async => FavouritesDB().clear(),
      ),
    );
  }

  Widget _buildVersionTile(BuildContext context) {
    return FutureBuilder(
      future: getVersion(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(title: Text("Loading..."));
        }
        return ListTile(title: Text("Version: ${snapshot.data}"));
      },
    );
  }

  void _showClearDataDialog({
    required BuildContext context,
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        title: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        icon: const Icon(Icons.warning_amber_rounded),
        content: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "NO",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await onConfirm();
              Navigator.of(context).pop();
            },
            child: Text(
              "YES",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyRestoredTheme(BuildContext context) async {
    final dynamic savedColorIndex = SettingsDB().get("color");
    final int colorIndex =
        savedColorIndex is int &&
            savedColorIndex >= 0 &&
            savedColorIndex < Colors.primaries.length
        ? savedColorIndex
        : 7;
    final MaterialColor color = Colors.primaries[colorIndex];
    final dynamic themeModeValue = SettingsDB().get("themeMode");
    final AdaptiveThemeMode themeMode = switch (themeModeValue) {
      "light" => AdaptiveThemeMode.light,
      "dark" => AdaptiveThemeMode.dark,
      "auto" => AdaptiveThemeMode.system,
      _ => AdaptiveThemeMode.system,
    };

    AdaptiveTheme.of(context).setTheme(
      light: AppTheme.buildLightTheme(color),
      dark: AppTheme.buildDarkTheme(color),
    );
    AdaptiveTheme.of(context).setThemeMode(themeMode);
  }

  Future<bool> _showRestoreConfirmation(BuildContext context) async {
    final bool? shouldRestore = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text("Restore backup"),
        icon: const Icon(Icons.restore_page_outlined),
        content: const Text(
          "This will replace your current favourites, reading history, and saved settings with the contents of the backup file.",
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Restore"),
          ),
        ],
      ),
    );

    return shouldRestore == true;
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildThemeModeTile(BuildContext context) {
    final AdaptiveThemeMode themeMode = AdaptiveTheme.of(context).mode;

    return ListTile(
      leading: Icon(_themeModeIcon(themeMode)),
      title: const Text("Theme mode"),
      subtitle: Text(_themeModeLabel(themeMode)),
      onTap: () => _showThemeModeDialog(context),
    );
  }

  Future<void> _showThemeModeDialog(BuildContext context) async {
    final AdaptiveThemeMode currentMode = AdaptiveTheme.of(context).mode;
    final AdaptiveThemeMode? selectedMode = await showDialog<AdaptiveThemeMode>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Choose theme mode"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildThemeModeOptionTile(
                context: context,
                currentMode: currentMode,
                mode: AdaptiveThemeMode.dark,
                icon: Icons.dark_mode_rounded,
                title: const Text("Dark"),
                subtitle: const Text("Always use night mode."),
              ),
              _buildThemeModeOptionTile(
                context: context,
                currentMode: currentMode,
                mode: AdaptiveThemeMode.light,
                icon: Icons.light_mode_rounded,
                title: const Text("Light"),
                subtitle: const Text("Always use light mode."),
              ),
              _buildThemeModeOptionTile(
                context: context,
                currentMode: currentMode,
                mode: AdaptiveThemeMode.system,
                icon: Icons.brightness_auto_rounded,
                title: const Text("Auto"),
                subtitle: const Text("Follow the system theme."),
              ),
            ],
          ),
        );
      },
    );

    if (selectedMode == null) return;
    await SettingsDB().put("themeMode", _themeModeSettingValue(selectedMode));
    if (context.mounted) {
      AdaptiveTheme.of(context).setThemeMode(selectedMode);
      setState(() {});
    }
  }

  Widget _buildThemeModeOptionTile({
    required BuildContext context,
    required AdaptiveThemeMode currentMode,
    required AdaptiveThemeMode mode,
    required IconData icon,
    required Widget title,
    required Widget subtitle,
  }) {
    final bool selected =
        _themeModeSettingValue(currentMode) == _themeModeSettingValue(mode);
    return ListTile(
      leading: Icon(icon),
      title: title,
      subtitle: subtitle,
      trailing: selected ? const Icon(Icons.check_rounded) : null,
      onTap: () => Navigator.of(context).pop(mode),
    );
  }

  IconData _themeModeIcon(AdaptiveThemeMode themeMode) {
    if (themeMode.isDark) return Icons.dark_mode_rounded;
    if (themeMode.isSystem) return Icons.brightness_auto_rounded;
    return Icons.light_mode_rounded;
  }

  String _themeModeLabel(AdaptiveThemeMode themeMode) {
    if (themeMode.isDark) return "Dark";
    if (themeMode.isSystem) return "Auto";
    return "Light";
  }

  String _themeModeSettingValue(AdaptiveThemeMode themeMode) {
    if (themeMode.isDark) return "dark";
    if (themeMode.isSystem) return "auto";
    return "light";
  }

  String _selectedThemeName() {
    final dynamic savedColor = SettingsDB().get("color");
    if (savedColor is int &&
        savedColor >= 0 &&
        savedColor < _themeColorNames.length) {
      return _themeColorNames[savedColor];
    }
    return "Cyan";
  }

  String _selectedTranslationName() {
    final dynamic savedTranslation = SettingsDB().get(
      "translation",
      defaultValue: 0,
    );
    if (savedTranslation is int &&
        savedTranslation >= 0 &&
        savedTranslation < Translation.values.length) {
      return Translation.values[savedTranslation].name;
    }
    return Translation.values.first.name;
  }

  String _selectedReciterName() {
    final dynamic savedReciter = SettingsDB().get("reciter", defaultValue: "1");
    return AppReciter.fromCode(savedReciter?.toString()).englishName;
  }
}

const List<String> _themeColorNames = <String>[
  "Red",
  "Pink",
  "Purple",
  "Deep purple",
  "Indigo",
  "Blue",
  "Light blue",
  "Cyan",
  "Teal",
  "Green",
  "Light green",
  "Lime",
  "Yellow",
  "Amber",
  "Orange",
  "Deep orange",
  "Brown",
  "Blue grey",
];
