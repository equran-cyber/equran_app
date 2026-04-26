import 'package:equran/backend/library.dart' show SettingsDB;
import 'package:flutter/material.dart';

class SettingsSwitch extends StatefulWidget {
  final String title;
  final String settingsKey;
  final String? subtitle;
  final ValueChanged<bool>? onChanged;
  final bool defaultValue;

  const SettingsSwitch({
    super.key,
    required this.title,
    required this.settingsKey,
    this.subtitle,
    this.onChanged,
    this.defaultValue = true,
  });

  @override
  State<SettingsSwitch> createState() => _SettingsSwitchState();
}

class _SettingsSwitchState extends State<SettingsSwitch> {
  void _setValue(bool value) {
    setState(() {
      SettingsDB().put(widget.settingsKey, value);
    });
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final bool currentValue = SettingsDB().get(
      widget.settingsKey,
      defaultValue: widget.defaultValue,
    );

    return ListTile(
      onTap: () => _setValue(!currentValue),
      title: Text(widget.title),
      subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
      trailing: Switch(value: currentValue, onChanged: _setValue),
    );
  }
}
