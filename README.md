# eQuran — Your Modern Quran Companion

[<img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png"
alt="Get it on F-Droid"
height="80">](https://f-droid.org/en/packages/com.app.equran/)

Experience the Quran with clarity, focus, and ease.

**eQuran** is designed to bring together reading, listening, and reflection in one seamless experience. With a clean Material 3 interface and thoughtfully crafted features, it helps you stay connected to the Quran—whether you're at home, on the go, or revisiting your last session.

---

## 🆕 What’s New in Beta 3

- 🌐 **Fully offline English transliteration** for ayahs in Card View
- ⚙️ New **Display transliteration** toggle in Reading settings
- 🎛️ Cleaner Card View hierarchy with improved action placement
- ▶️ Unified media control bar behavior between reading modes
- 🌙 Quick **theme toggle integrated in the sidebar**
- 📱 Ongoing UI polish and interaction refinements for a smoother reading/listening flow

---

## ✨ Why You’ll Love eQuran

- 📖 Effortless reading with a clean, distraction-free design
- 🎧 Smooth audio playback for both Surahs and individual ayahs
- 🔄 Instantly resume where you left off
- 📱 Works beautifully across phones, tablets, and desktops
- 🌙 Built for daily recitation, memorization, and reflection

---

## 📖 Beautiful Reading Experience

- Browse by **Surah or Juz**
- Smooth, intuitive navigation between verses
- Quick access to Surah details and verse counts
- Optimized for both mobile and large screens

---

## 🔁 Never Lose Your Place

- Automatically saves your **last read position**
- Quickly return to recent ayahs
- Designed for seamless continuity across sessions

---

## 🎧 Powerful Audio Experience

- Stream high-quality recitations instantly
- Play **individual ayahs directly from the page**
- Download Surahs for **offline listening**
- Automatically switches to offline audio when available

**Playback controls:**
- Play, pause, next, previous
- Shuffle and loop modes
- Adjustable playback speed

---

## 🎙️ Multiple Reciters

- Mishary Rashid Al Afasy
- Abu Bakr Al Shatri
- Nasser Al Qatami
- Yasser Al Dosari
- Hani Ar Rifai

---

## 🎵 Background Playback

- Listen while using other apps
- Control playback from system media controls

---

## ⭐ Favorites & Personalization

- Save important ayahs for quick access
- Theme-aware design
- Modern Material 3 interface

---

## 📱 Built for Every Device

- Optimized for phones, tablets, foldables, and desktops
- Adaptive layouts for reading and playback
- Improved readability on larger screens

---

## 🌿 Simple. Modern. Focused.

eQuran is built for those who want a clean, reliable, and distraction-free Quran experience.

Whether you're reading daily, memorizing, or listening on the go, **eQuran helps you stay consistent and focused.**

## Requirements for building the app

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
