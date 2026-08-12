# Android APK build

The canonical Godot project remains stored in `MaximumClonage_Runtime_Project.zip`.
The Android workflow extracts that archive into a temporary runner directory; generated
Godot imports, reconstructed validation inputs, and the APK are never committed.

On every push, or when manually dispatched, `.github/workflows/android-apk.yml`:

1. extracts the existing runtime project archive;
2. installs Godot 4.7.1 and its matching export templates;
3. configures JDK 17 and Android SDK Platform 36 / Build Tools 36.0.0;
4. runs the supplied structural validator, Godot resource import, and smoke test;
5. exports and verifies `MaximumClonage.apk`; and
6. uploads it as the `MaximumClonage-Android` Actions artifact.

The produced APK is debug-signed for testing. A store release still requires a private
release keystore and final release configuration.
