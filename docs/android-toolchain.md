# Android toolchain compatibility

The workflows pin Flutter 3.41.4. Keep its Android build on the legacy Kotlin
Gradle plugin and AGP 8 until a separate Flutter migration is validated.

The maintained combination is:

| Component | Version | Compatibility basis |
| --- | --- | --- |
| Flutter | 3.41.4 | Existing workflow pin |
| Android Gradle plugin | 8.13.2 | Latest AGP 8 maintenance release; supports API 36 and Kotlin 2.3 |
| Gradle | 8.14.4 | Meets AGP's Gradle 8.13 minimum and includes the 8.14 security fixes |
| Kotlin Gradle plugin | 2.3.21 | Supports Gradle 8.14 and AGP 8.13; its class files are supported by AGP 8.13.2's R8 |
| JDK | 17 | AGP's required JDK and the existing Android workflow version |

Kotlin's JVM target uses the typed `kotlin.compilerOptions` DSL. Kotlin 2.3 no
longer accepts the deprecated `android.kotlinOptions.jvmTarget` assignment;
the Java and Kotlin targets remain aligned at JVM 17.

AGP 9.5.1 with Gradle 9.8.2 and Kotlin 2.4.21 fails while applying this
application's `kotlin-android` plugin: AGP 9 enables built-in Kotlin by default.
Flutter's temporary AGP 9 compatibility for the legacy plugin landed in 3.44;
enabling built-in Kotlin requires Flutter 3.47 or later. Do not work around this
by disabling version checks or changing the Flutter pin as part of a tooling
update.

Dependabot continues grouped updates within the compatible lane. Its bounds
defer AGP 9+, Gradle 9+, and Kotlin 2.4+. Kotlin 2.4 requires R8 9.1.29 or later,
whereas AGP 8.13.2 bundles R8 8.13.19. These are compatibility bounds, not audit
exceptions. Revisit them together when upgrading Flutter and migrating the
application and its Android plugins to the new AGP DSL and Kotlin integration.

Validate Android tooling changes with the pinned Flutter SDK and JDK 17:

```sh
flutter pub get --enforce-lockfile
make check
flutter build apk --debug --no-pub --target-platform android-arm64
```

Use an installed Android SDK with the SDK/NDK versions requested by Flutter.
The debug build validates compilation without publishing or creating a release.

Sources:

- [Flutter's AGP 9 and built-in Kotlin migration](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin)
- [AGP 8.13.2 compatibility and Kotlin 2.3 support](https://developer.android.com/build/releases/agp-8-13-0-release-notes)
- [Kotlin Gradle plugin compatibility matrix](https://kotlinlang.org/docs/gradle-configure-project.html)
- [Android's Kotlin and R8 compatibility table](https://developer.android.com/build/kotlin-support)
- [Gradle 8.14.4 security fixes](https://docs.gradle.org/8.14.4/release-notes.html)
