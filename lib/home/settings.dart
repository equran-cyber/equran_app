import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:equran/backend/library.dart'
    show BookmarkDB, FavouritesDB, SettingsDB;
import 'package:equran/utils/library.dart';
import 'package:equran/widgets/library.dart'
    show FontSlider, PlayBackSlider, SettingsSwitch;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:quran/quran.dart' show Translation;
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<String> getVersion() async {
    final info = await PackageInfo.fromPlatform();
    return "${info.version}+${info.buildNumber}";
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: ListView(
        children: [
          ListTile(
            title: Text(
              "General",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SettingsSwitch(
            title: "Vibration",
            subtitle: "Enable haptic feedback when navigating.",
            settingsKey: "vibration",
          ),
          const SettingsSwitch(
            title: "Card View",
            subtitle: "Displays each verse separately, or all in one page.",
            settingsKey: "viewMode",
          ),
          const SettingsSwitch(
            title: "Show reading history",
            settingsKey: "showLastRead",
            subtitle: "Shows you up to 7 last read Surahs.",
          ),
          const SettingsSwitch(
            title: "Enable Translation",
            subtitle: "Enables translation for each verse.",
            settingsKey: "enableTranslation",
          ),
          ListTile(
            title: const Text("Translation"),
            subtitle: const Text("Choose your preferred language."),
            onTap: () {
              List<Translation> items = Translation.values;
              int selected = SettingsDB().get("translation", defaultValue: 0);
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return StatefulBuilder(
                    // Use StatefulBuilder to maintain radio state
                    builder: (context, setState) {
                      return AlertDialog(
                        title: const Text("Select Language"),
                        content: SingleChildScrollView(
                          child: Column(
                            // Column for radio buttons
                            children: items.asMap().entries.map((entry) {
                              int index = entry.key;
                              return RadioListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: Text(entry.value.name),
                                value: index,
                                groupValue: selected,
                                onChanged: (int? value) {
                                  SettingsDB().put("translation", value);
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
          ),
          ListTile(
            title: const Text("Reciter"),
            subtitle: const Text("Choose your preferred reciter."),
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
                    // Use StatefulBuilder to maintain radio state
                    builder: (context, setState) {
                      return AlertDialog(
                        title: const Text("Select Reciter"),
                        content: SingleChildScrollView(
                          child: Column(
                            // Column for radio buttons
                            children: items.asMap().entries.map((entry) {
                              int index = entry.key;
                              return RadioListTile<AppReciter>(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: Text(entry.value.englishName),
                                value: entry.value,
                                groupValue: selectedReciter,
                                onChanged: (value) {
                                  if (value == null) return;
                                  SettingsDB().put("reciter", value.code);
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
          ),
          const PlayBackSlider(),
          ListTile(
            title: Text(
              "Appearance",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Choose a Color'),
                    icon: const Icon(Icons.format_paint_rounded),
                    content: Wrap(
                      runSpacing: 10,
                      spacing: 10.0, // Add spacing between circles
                      children: List.generate(Colors.primaries.length, (index) {
                        final color = Colors.primaries[index];
                        return InkWell(
                          onTap: () {
                            SettingsDB().put("color", index);

                            AdaptiveTheme.of(context).setTheme(
                              light: ThemeData(colorSchemeSeed: color),
                              dark: ThemeData(
                                colorSchemeSeed: color,
                                brightness: Brightness.dark,
                              ),
                            );
                          },
                          child: CircleAvatar(
                            backgroundColor: color,
                            radius: 18.0,
                            // Adjust radius as needed
                          ),
                        );
                      }),
                    ),
                  );
                },
              );
            },
            title: const Text("Theme"),
            subtitle: const Text("Pick your desired color scheme."),
          ),
          const FontSlider(),
          ListTile(
            title: Text(
              "Data",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            title: const Text("Clear reading history"),
            subtitle: const Text("Removes all your reading history."),
            onTap: () => showDialog<void>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                title: Text(
                  "Clear reading history",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                icon: const Icon(Icons.warning_amber_rounded),
                content: Text(
                  "WARNING: Are you sure you want to clear your reading history?",
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
                      await BookmarkDB().clear();
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
            ),
          ),
          ListTile(
            title: const Text("Clear Favourites"),
            subtitle: const Text("Removes all verses you have liked. "),
            onTap: () => showDialog<void>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                title: Text(
                  "Clear Favourites",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                icon: const Icon(Icons.warning_amber_rounded),
                content: Text(
                  "WARNING: Are you sure you want to clear favourites?",
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
                      await FavouritesDB().clear();
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
            ),
          ),
          Divider(),
          FutureBuilder(
            future: getVersion(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Text("Loading...");
              }
              return ListTile(
                title: Text(
                  "Version: ${snapshot.data}",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
