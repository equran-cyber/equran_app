String formatCompactNumber(double value) {
  final String compact = value.toStringAsPrecision(3);
  return compact.contains('.')
      ? compact.replaceFirst(RegExp(r'\.?0+$'), '')
      : compact;
}

String formatDurationLabel(Duration duration) {
  final String minutes = duration.inMinutes
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  final String seconds = duration.inSeconds
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  if (duration.inHours > 0) {
    return '${duration.inHours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
