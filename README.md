# equran_app

Application for reading the Holy Quran. 

[<img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png"
alt="Get it on F-Droid"
height="80">](https://f-droid.org/en/packages/com.app.equran/)

## Prerequisites

- Flutter SDK (stable channel)
- Git
- Platform toolchain for your target:
  - Android: Android Studio + Android SDK
  - Linux: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`
  - Windows: Visual Studio with Desktop C++ workload

## Clone the project

```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd equran-app
```

## Install dependencies

```bash
flutter pub get
```

## Run the app (debug)

### Android

```bash
flutter run -d android
```

### Linux

```bash
flutter config --enable-linux-desktop
flutter run -d linux
```

### Windows

```bash
flutter config --enable-windows-desktop
flutter run -d windows
```

### Web

```bash
flutter run -d chrome
```

## Build release artifacts locally

### Android split APKs

```bash
flutter build apk --release --split-per-abi
```

Output folder:

`build/app/outputs/flutter-apk/`

### Linux release bundle

```bash
flutter build linux --release
```

Output folder:

`build/linux/x64/release/bundle/`

### Windows release bundle

```bash
flutter build windows --release
```

Output folder:

`build/windows/x64/runner/Release/`

## GitHub Actions release flow

Workflow file: [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml)

On every push to `main`, CI will:

1. Read app version from `pubspec.yaml` (for example `2.0.0+13`)
2. Build:
   - Android split APKs
   - Linux release bundle
   - Windows release bundle
3. Create/update a Git tag matching the `pubspec.yaml` version
4. Create/update the GitHub Release for that tag and upload artifacts

## Versioning

Version format in `pubspec.yaml`:

`version: <semantic-version>+<build-number>`

Example:

`version: 2.0.0+13`
