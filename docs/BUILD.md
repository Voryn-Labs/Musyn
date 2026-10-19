# Musyn 0.1 build and release

Identity: **Musyn by Voryn Labs**, `com.vorynlabs.musyn`, `0.1.0+1`, iOS 15+.
This is a fresh app; no legacy migration or URL schemes are shipped.

1. Use Flutter 3.47.7 / Dart 3.13.5 and full Xcode/CocoaPods for iOS.
2. Run `flutter pub get`, `flutter analyze`, `flutter test` and
   `python3 scripts/verify_branding.py`.
3. Run the **Build Musyn iOS** workflow manually. A normal push runs checks only.
   Enable Publish to create the 0.1 GitHub prerelease after the build succeeds.
4. CI builds without signing, packages `Musyn.ipa`, verifies its native identity,
   creates SHA-256, and writes `source.json`/`apps.json` from the real binary.
   The empty development feed does not advertise a nonexistent build.
5. CI publishes the IPA, checksum and feed, then commits the populated feed to
   main. It refuses to overwrite an existing release/version.

Install the unsigned IPA using your own certificate/compatible signer or a
compatible LiveContainer host. A successful unsigned build is not App Store
signing, notarization, or physical-device playback acceptance. Keep the preview
label until the native lock-screen/source/download checklist in VERIFICATION.md
has been completed.

Brand assets are in `assets/branding`. The source icon is opaque 1024×1024;
iOS applies its own icon mask. Native launch and Flutter initialization show the
same folded music mark. Version changes must update pubspec and
`lib/constants/version.dart` together; the branding verifier checks this.
