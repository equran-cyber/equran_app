import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';

class AppSelectionOption<T> {
  const AppSelectionOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.leading,
  });

  final T value;
  final String title;
  final String? subtitle;
  final Widget? leading;
}

class AppSelectionDialog<T> extends StatelessWidget {
  const AppSelectionDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.selectedValue,
    required this.options,
    this.maxWidth = 440,
    this.maxHeight = 560,
  });

  final String title;
  final IconData icon;
  final T selectedValue;
  final List<AppSelectionOption<T>> options;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final BorderRadius borderRadius = BorderRadius.circular(AppRadii.large);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      backgroundColor: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ColoredBox(
              color: colorScheme.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  children: <Widget>[
                    Icon(icon, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
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
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ClipRect(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final AppSelectionOption<T> option = options[index];
                    final bool isSelected = option.value == selectedValue;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Material(
                        color: isSelected
                            ? colorScheme.primaryContainer.withValues(
                                alpha: 0.42,
                              )
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: option.leading,
                          title: Text(option.title),
                          subtitle: option.subtitle == null
                              ? null
                              : Text(option.subtitle!),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: colorScheme.primary,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(option.value),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
