# eQuran

> A clean, modern Quran companion for focused reading, listening, and daily reflection.

<p align="left">
  <a href="https://github.com/ya27hw/equran_app/releases">
    <img alt="Latest GitHub release" src="https://img.shields.io/github/v/release/ya27hw/equran_app?sort=semver&style=for-the-badge">
  </a>
  <a href="https://github.com/ya27hw/equran_app/stargazers">
    <img alt="GitHub stars" src="https://img.shields.io/github/stars/ya27hw/equran_app?style=for-the-badge">
  </a>
  <a href="https://github.com/ya27hw/equran_app/actions/workflows/deploy.yml">
    <img alt="Build and release workflow" src="https://img.shields.io/github/actions/workflow/status/ya27hw/equran_app/deploy.yml?branch=main&label=release%20build&style=for-the-badge">
  </a>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-%E2%89%A53.41.7-02569B?logo=flutter&logoColor=white&style=for-the-badge">
  <img alt="Release targets" src="https://img.shields.io/badge/release%20targets-Android%20%7C%20Linux%20%7C%20Windows-0f766e?style=for-the-badge">
</p>

<p align="left">
  <a href="https://f-droid.org/en/packages/com.app.equran/">
    <img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png" alt="Get it on F-Droid" height="72">
  </a>
</p>

eQuran brings together Quran reading, ayah and surah audio playback, offline audio downloads, tafsir, transliteration, favourites, and reading progress in a Material 3 Flutter app. The interface is intentionally quiet: useful controls stay close at hand without pulling attention away from the text.

## Preview

Screenshots are not currently included in this repository. Add images under `metadata/en-US/images/` or a `screenshots/` directory, then replace the placeholders below.

| Reading | Audio | Favourites |
| --- | --- | --- |
| _Screenshot placeholder_ | _Screenshot placeholder_ | _Screenshot placeholder_ |

## Features

- Read the Quran by **Surah** or **Juz**.
- Switch between a focused card view and a full-page reading view.
- Resume from the last-read ayah.
- Play complete surahs or individual ayahs.
- Download surah or ayah audio for offline listening.
- Choose from multiple reciters.
- Use background playback and system media controls.
- Save favourite ayahs with optional notes.
- View English translation, transliteration, and tafsir content where available.
- Share ayahs as generated images.
- Use responsive layouts across phone, tablet, desktop, and foldable-sized screens.

## App Details

| Item | Value |
| --- | --- |
| Package name | `equran` |
| Android application ID | `com.app.equran` |
| Current version | `2.7.3+44` |
| Flutter SDK | `>=3.38.4` |
| Dart SDK | `>=3.10.3 <4.0.0` |
| Release workflow targets | Android split APKs, Linux bundle, Windows bundle |
| License | Not specified in this repository |

## Tech Stack

- **Flutter** with Material 3.
- **Hive** for lightweight local persistence.
- **just_audio**, **just_audio_background**, and **audioplayers** for playback flows.
- **quran** package for Quran text and metadata.
- **flutter_map** for the prayer location picker with open map tiles.
- Local assets for Hafs font, transliteration, daily content, and tafsir data.

### Map Tiles

The prayer location picker uses `flutter_map` with an OpenStreetMap-compatible
tile URL and a configured User-Agent. Public tile servers have usage policies;
production builds with significant traffic should use an appropriate tile
provider or self-hosted tiles and comply with the chosen provider's terms.

## Getting Started

### Requirements

- Flutter SDK on the stable channel.
- Git.
- Platform tooling for your target:
  - Android: Android Studio and Android SDK.
  - Linux: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, plus GStreamer development packages for audio builds.
  - Windows: Visual Studio with the Desktop development with C++ workload.

### Clone

```bash
git clone https://github.com/ya27hw/equran_app.git
cd equran_app
```

### Install Dependencies

```bash
flutter pub get
```

### Run Locally

```bash
flutter run
```

You can also target a specific platform:

```bash
flutter run -d android
flutter run -d linux
flutter run -d windows
flutter run -d chrome
```

## Build

### Android Split APKs

```bash
flutter build apk --release --split-per-abi
```

Artifacts are written to:

```text
build/app/outputs/flutter-apk/
```

### Linux

```bash
flutter config --enable-linux-desktop
flutter build linux --release
```

Artifacts are written to:

```text
build/linux/x64/release/bundle/
```

### Windows

```bash
flutter config --enable-windows-desktop
flutter build windows --release
```

Artifacts are written to:

```text
build/windows/x64/runner/Release/
```

## Release Flow

The release workflow lives at [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml).

On pushes to `main` or manual workflow dispatch, the workflow:

1. Reads the version from `pubspec.yaml`.
2. Builds Android split APKs, a Linux release bundle, and a Windows release bundle.
3. Creates a tag from the semantic version, for example `v2.7.3`.
4. Publishes a GitHub Release with generated release notes and build artifacts.

Existing tags are detected before release jobs run, so previously published versions are skipped.

## Project Structure

```text
lib/
  backend/      Data, downloads, playback helpers, settings, and services
  home/         Main app screens and reading/player experiences
  utils/        Theme, responsive, and display helpers
  widgets/      Shared UI components
assets/
  fonts/        Hafs Quran font
  tafsir/       Tafsir JSON assets
  transliteration/
metadata/       Store listing metadata and app icon
```

## Contributing

Contributions are welcome when they stay aligned with the app’s focused reading and listening experience.

Before opening a pull request:

1. Keep changes scoped and reviewable.
2. Run formatting:

   ```bash
   dart format .
   ```

3. Run analysis:

   ```bash
   flutter analyze
   ```

4. Test the affected platform or feature path.
5. Update documentation when behavior, setup, or release steps change.

## License

No license file is currently included in this repository. Add a `LICENSE` file before distributing or reusing the source under explicit open-source terms.
