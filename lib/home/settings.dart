import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:equran/backend/library.dart'
    show BookmarkDB, FavouritesDB, SettingsDB;
import 'package:equran/backend/backup_service.dart';
import 'package:equran/utils/app_theme.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:equran/utils/library.dart';
import 'package:equran/widgets/library.dart'
    show
        AppSelectionDialog,
        AppSelectionOption,
        FontSlider,
        PlayBackSlider,
        SettingsSwitch;
import 'package:flutter/material.dart';
import 'package:quran/quran.dart' show Translation;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const String _appDownloadUrl =
    'https://f-droid.org/en/packages/com.app.equran/';
const String _issueReportUrl = 'https://github.com/ya27hw/equran_app/issues';
const String _contactEmail = 'equran@elbaesy.com';

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
    final bool showTranslationControls = cardViewEnabled && translationEnabled;

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
            children: <Widget>[
              const SettingsSwitch(
                title: "Vibration",
                subtitle: "Enable haptic feedback when navigating.",
                settingsKey: "vibration",
              ),
              const SettingsSwitch(
                title: "Show reading history",
                settingsKey: "showLastRead",
                subtitle: "Shows you up to 7 last read Surahs.",
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('About this app'),
                onTap: () => _showAboutApp(context),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share app'),
                onTap: () => _shareApp(context),
              ),
              ListTile(
                leading: const Icon(Icons.feedback_outlined),
                title: const Text('Feedback / Contact'),
                onTap: () => _openFeedbackContactPage(context),
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
                  title: "Display Translation",
                  subtitle: "Display translation for each verse in card view.",
                  settingsKey: "enableTranslation",
                  onChanged: (_) => setState(() {}),
                ),
              _buildTranslationTile(context),
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
      onTap: () async {
        final int selected = SettingsDB().get("translation", defaultValue: 0);
        final int? value = await _showSelectionDialog<int>(
          context: context,
          title: "Translation Language",
          icon: Icons.translate_rounded,
          selectedValue: selected,
          options:
              Translation.values
                  .asMap()
                  .entries
                  .map(
                    (entry) => AppSelectionOption<int>(
                      value: entry.key,
                      title: translationDisplayName(entry.value),
                    ),
                  )
                  .toList()
                ..sort((a, b) => a.title.compareTo(b.title)),
        );
        if (value == null) return;
        SettingsDB().put("translation", value);
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Future<T?> _showSelectionDialog<T>({
    required BuildContext context,
    required String title,
    required IconData icon,
    required T selectedValue,
    required List<AppSelectionOption<T>> options,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => AppSelectionDialog<T>(
        title: title,
        icon: icon,
        selectedValue: selectedValue,
        options: options,
      ),
    );
  }

  Widget _buildReciterTile(BuildContext context) {
    return ListTile(
      title: const Text("Reciter"),
      subtitle: Text(_selectedReciterName()),
      onTap: () async {
        final List<AppReciter> items = AppReciter.values.toList()
          ..sort(
            (a, b) => a.englishName.toLowerCase().compareTo(
              b.englishName.toLowerCase(),
            ),
          );
        final selected = SettingsDB().get("reciter", defaultValue: "1");
        final selectedReciter = AppReciter.fromCode(selected);
        final AppReciter? value = await _showSelectionDialog<AppReciter>(
          context: context,
          title: "Reciter",
          icon: Icons.record_voice_over_rounded,
          selectedValue: selectedReciter,
          options: items
              .map(
                (reciter) => AppSelectionOption<AppReciter>(
                  value: reciter,
                  title: reciter.englishName,
                ),
              )
              .toList(),
        );
        if (value == null) return;
        SettingsDB().put("reciter", value.code);
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildThemeColorTile(BuildContext context) {
    return ListTile(
      onTap: () async {
        final int? selectedColor = await _showColorPickerDialog(context);
        if (selectedColor == null) return;
        SettingsDB().put("color", selectedColor);
        if (mounted) {
          setState(() {});
        }

        final MaterialColor color = Colors.primaries[selectedColor];
        if (context.mounted) {
          AdaptiveTheme.of(context).setTheme(
            light: AppTheme.buildLightTheme(color),
            dark: AppTheme.buildDarkTheme(color),
          );
        }
      },
      title: const Text("Color scheme"),
      subtitle: Text(_selectedThemeName()),
    );
  }

  Future<int?> _showColorPickerDialog(BuildContext context) {
    final dynamic savedColor = SettingsDB().get("color");
    final int selectedColor =
        savedColor is int &&
            savedColor >= 0 &&
            savedColor < Colors.primaries.length
        ? savedColor
        : 7;

    return showDialog<int>(
      context: context,
      builder: (context) {
        final ThemeData theme = Theme.of(context);
        final ColorScheme colorScheme = theme.colorScheme;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ),
          backgroundColor: colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.large),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.large),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.format_paint_rounded,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Color Scheme',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      runSpacing: 12,
                      spacing: 12,
                      children: List.generate(Colors.primaries.length, (index) {
                        final MaterialColor color = Colors.primaries[index];
                        final bool isSelected = index == selectedColor;
                        return InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => Navigator.of(context).pop(index),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(
                                color: isSelected
                                    ? colorScheme.onSurface
                                    : colorScheme.outlineVariant,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
    final AdaptiveThemeMode? selectedMode =
        await _showSelectionDialog<AdaptiveThemeMode>(
          context: context,
          title: "Theme Mode",
          icon: Icons.palette_outlined,
          selectedValue: currentMode,
          options: const <AppSelectionOption<AdaptiveThemeMode>>[
            AppSelectionOption<AdaptiveThemeMode>(
              value: AdaptiveThemeMode.dark,
              title: "Dark",
              subtitle: "Always use night mode.",
              leading: Icon(Icons.dark_mode_rounded),
            ),
            AppSelectionOption<AdaptiveThemeMode>(
              value: AdaptiveThemeMode.light,
              title: "Light",
              subtitle: "Always use light mode.",
              leading: Icon(Icons.light_mode_rounded),
            ),
            AppSelectionOption<AdaptiveThemeMode>(
              value: AdaptiveThemeMode.system,
              title: "Auto",
              subtitle: "Follow the system theme.",
              leading: Icon(Icons.brightness_auto_rounded),
            ),
          ],
        );

    if (selectedMode == null) return;
    await SettingsDB().put("themeMode", _themeModeSettingValue(selectedMode));
    if (context.mounted) {
      AdaptiveTheme.of(context).setThemeMode(selectedMode);
      setState(() {});
    }
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
      return translationDisplayName(Translation.values[savedTranslation]);
    }
    return translationDisplayName(Translation.values.first);
  }

  String _selectedReciterName() {
    final dynamic savedReciter = SettingsDB().get("reciter", defaultValue: "1");
    return AppReciter.fromCode(savedReciter?.toString()).englishName;
  }

  Future<void> _showAboutApp(BuildContext context) async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    if (!context.mounted) return;

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    showAboutDialog(
      context: context,
      applicationName: 'eQuran',
      applicationVersion: 'Version ${packageInfo.version}',
      applicationIcon: Icon(
        Icons.menu_book_rounded,
        color: colorScheme.primary,
        size: 40,
      ),
      children: const <Widget>[
        SizedBox(height: 16),
        Text(
          'eQuran is a modern Quran companion designed for focused reading, listening, and daily reflection.',
        ),
      ],
    );
  }

  Future<void> _shareApp(BuildContext context) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'eQuran',
          subject: 'Download eQuran',
          text: 'Download eQuran on F-Droid: $_appDownloadUrl',
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      _showMessage(context, 'Unable to open the share sheet.');
    }
  }

  void _openFeedbackContactPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const _FeedbackContactPage(),
      ),
    );
  }
}

class _FeedbackContactPage extends StatelessWidget {
  const _FeedbackContactPage();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback / Contact')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Report issues'),
            subtitle: const Text('Open the GitHub issue tracker.'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () async {
              final Uri uri = Uri.parse(_issueReportUrl);
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
                  context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unable to open issue tracker.')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email support'),
            subtitle: Text(_contactEmail),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () async {
              final Uri uri = Uri(
                scheme: 'mailto',
                path: _contactEmail,
                queryParameters: <String, String>{'subject': 'eQuran feedback'},
              );
              if (!await launchUrl(uri) && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unable to open email client.')),
                );
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              'We appreciate your feedback and suggestions.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
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
