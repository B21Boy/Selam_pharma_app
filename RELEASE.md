# Release Checklist for SHMed

This document collects the steps required to prepare and publish a new Android (and eventually iOS/web) release of the app. Refer to the **Pre‑release checklist** in the user conversation for general guidance; the list below is tailored to this repository.

---

## 1. Versioning

1. Choose the next version number and build code. Android uses `versionName` (e.g. `1.2.0`) and `versionCode` (integer) from `pubspec.yaml`.
2. Update `pubspec.yaml` manually or via the helper script below:
   ```sh
   # bump version to 1.0.2+3
   ./scripts/release.sh 1.0.2+3
   ```
3. `git push` and create a tag:
   ```sh
   git tag -a v1.0.2 -m "Release 1.0.2"
   git push --tags
   ```
4. The script also runs `flutter pub get` and commits the updated pubspec for you.

> **Important:** each upload to Play Console must have a **higher** version code than the previous one.

## 2. Signing

- Ensure `android/app/release-key.jks` exists and matches the `key.properties` values.
- Do **not** use the debug keystore. The Gradle config in `android/app/build.gradle.kts` reads `key.properties` automatically.
- Keep the keystore safe and back it up to a secure vault/CI secret manager.

## 3. Building

Run one or both of the following from the project root:

```sh
# preferred bundle for Play
flutter build appbundle --release

# or APKs per ABI (may not be allowed on Play long‑term)
flutter build apk --release --split-per-abi
```

Outputs are placed under `build/app/outputs` (see Gradle logs).

## 4. Testing

1. Install the generated bundle or APK on real devices or emulators representing different Android versions and screen sizes.
2. Verify critical flows: authentication, network sync, notifications, offline behaviour, deep links, etc.
3. Use `flutter run --release --trace-startup` if you need startup logs.
4. Upload to an internal/closed track in Play Console and perform a smoke test with teammates before rolling out widely.

## 5. Play Store listing

- Prepare high‑resolution screenshots for phones/tablets; crop or annotate if necessary.
- Write a short and full description (localize if you support multiple languages).
- Supply app icon, feature graphic, promo assets, and a privacy policy URL.
- Set the content rating and answer the data safety questionnaire.

## 6. Manifest & permissions

- Check `android/app/src/main/AndroidManifest.xml` for unneeded permissions or debug flags.
- Remove any `android:debuggable="true"` or test-only markers.

## 7. Target/min SDK

- `compileSdk` and `targetSdk` are currently set to **36** in `build.gradle.kts`.
- Update if Google raises the minimum target requirement; keep `minSdk` at the lowest version you support (currently 21).

## 8. ProGuard/R8 & size

The release build already enables R8 shrinking and obfuscation. After building:

```sh
# view size of AAB or APK
ls -lh build/app/outputs/**/*.aab build/app/outputs/**/*.apk
```

Add ProGuard rules under `android/app/proguard-rules.pro` if you notice missing classes at runtime.

## 9. Analytics & crash reporting

Verify Firebase/Crashlytics initializes by running the release build and checking the console for a test crash.
Consider adding a hidden diagnostics screen or `--flavor debug` build.

## 10. Legal & store requirements

- Confirm compliance with Play policies (ads, permissions, user data, etc.).
- Restrict any Google API keys (e.g. Maps) using the Cloud Console.
- Fill out export compliance, EU privacy, and other questionnaire items.

## 11. Release strategy

- Use a staged rollout (e.g. 5 %) and monitor crash/ANR reports before widening.
- Draft release notes with bullet points summarizing the changes.

---

### Helper script

See `scripts/release.sh` for a simple helper that bumps the version, runs `pub get` and builds.

```sh
# example usage
./scripts/release.sh 1.0.2+3
```

Feel free to adapt or integrate this into your CI/CD pipeline (Fastlane, gplaycli, etc.).

---

Feel free to update this document whenever the release process changes. Keep a backup copy of `key.properties` and `release-key.jks` in a secure location.
