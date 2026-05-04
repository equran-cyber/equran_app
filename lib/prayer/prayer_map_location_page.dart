import 'package:equran/prayer/manual_prayer_location_page.dart';
import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

typedef PrayerLocationPicker =
    Future<PrayerLocation?> Function(
      BuildContext context,
      PrayerLocation? initialLocation,
    );

Future<PrayerLocation?> showPrayerMapLocationPicker(
  BuildContext context,
  PrayerLocation? initialLocation,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<PrayerLocation>(
      builder: (BuildContext context) =>
          PrayerMapLocationPage(initialLocation: initialLocation),
    ),
  );
}

PrayerLocation prayerLocationFromMapSelection({
  required double latitude,
  required double longitude,
}) {
  return PrayerLocation(
    latitude: latitude,
    longitude: longitude,
    label: 'Selected location',
    mode: PrayerLocationMode.manual,
  );
}

class PrayerMapLocationPage extends StatefulWidget {
  const PrayerMapLocationPage({super.key, this.initialLocation});

  final PrayerLocation? initialLocation;

  @override
  State<PrayerMapLocationPage> createState() => _PrayerMapLocationPageState();
}

class _PrayerMapLocationPageState extends State<PrayerMapLocationPage> {
  late LatLng _selectedCenter;

  @override
  void initState() {
    super.initState();
    final PrayerLocation? initialLocation = widget.initialLocation;
    _selectedCenter = initialLocation == null
        ? const LatLng(0, 0)
        : LatLng(initialLocation.latitude, initialLocation.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose on map')),
      body: Stack(
        children: <Widget>[
          FlutterMap(
            options: MapOptions(
              initialCenter: _selectedCenter,
              initialZoom: widget.initialLocation == null ? 2 : 13,
              minZoom: 2,
              maxZoom: 18,
              backgroundColor: colors.surfaceContainerHighest,
              onPositionChanged: (MapCamera camera, bool hasGesture) {
                setState(() {
                  _selectedCenter = camera.center;
                });
              },
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                // Public tile servers have usage policies. Significant
                // production traffic should use a suitable provider or
                // self-hosted tiles, and keep a valid User-Agent configured.
                userAgentPackageName: 'com.app.equran',
                errorTileCallback: (_, _, _) {},
              ),
              RichAttributionWidget(
                attributions: <SourceAttribution>[
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    textStyle: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -18),
                child: Icon(
                  Icons.location_pin,
                  size: 48,
                  color: colors.primary,
                  shadows: <Shadow>[
                    Shadow(
                      color: colors.shadow.withValues(alpha: 0.32),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary,
                  border: Border.all(color: colors.surface, width: 2),
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: SafeArea(
              top: false,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  border: Border.all(color: colors.outlineVariant),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Selected location',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prayerMapCoordinatePreview(
                          _selectedCenter.latitude,
                          _selectedCenter.longitude,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _useSelectedLocation,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Use this location'),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: _enterCoordinatesManually,
                        icon: const Icon(Icons.edit_location_alt_outlined),
                        label: const Text('Enter coordinates manually'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _useSelectedLocation() {
    Navigator.of(context).pop(
      prayerLocationFromMapSelection(
        latitude: _selectedCenter.latitude,
        longitude: _selectedCenter.longitude,
      ),
    );
  }

  Future<void> _enterCoordinatesManually() async {
    final PrayerLocation? location = await Navigator.of(context).push(
      MaterialPageRoute<PrayerLocation>(
        builder: (BuildContext context) => ManualPrayerLocationPage(
          initialLocation: prayerLocationFromMapSelection(
            latitude: _selectedCenter.latitude,
            longitude: _selectedCenter.longitude,
          ),
        ),
      ),
    );
    if (location == null || !mounted) return;
    Navigator.of(context).pop(location);
  }
}

String prayerMapCoordinatePreview(double latitude, double longitude) {
  return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}
