#!/usr/bin/env bash
# Runs in CI after `flutter create` generated the android/ folder:
#   1. sets the app name shown on the phone;
#   2. when android/key.properties exists, signs release builds with that key
#      (otherwise the Flutter template keeps its debug key).
set -euo pipefail

manifest=android/app/src/main/AndroidManifest.xml
sed -i 's/android:label="[^"]*"/android:label="المُهرة"/' "$manifest"
grep -q 'android:label="المُهرة"' "$manifest"

if [ ! -f android/key.properties ]; then
  echo "android_setup: no key.properties — release build uses the debug key"
  exit 0
fi

marker="// almuhra-release-signing"
if [ -f android/app/build.gradle.kts ]; then
  gradle=android/app/build.gradle.kts
  grep -q "$marker" "$gradle" || cat >> "$gradle" <<'KTS'

// almuhra-release-signing
val almuhraKeyProps = java.util.Properties().apply {
    load(java.io.FileInputStream(rootProject.file("key.properties")))
}
android {
    signingConfigs {
        create("almuhraRelease") {
            keyAlias = almuhraKeyProps.getProperty("keyAlias")
            keyPassword = almuhraKeyProps.getProperty("keyPassword")
            storeFile = file(almuhraKeyProps.getProperty("storeFile"))
            storePassword = almuhraKeyProps.getProperty("storePassword")
        }
    }
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("almuhraRelease")
        }
    }
}
KTS
else
  gradle=android/app/build.gradle
  grep -q "$marker" "$gradle" || cat >> "$gradle" <<'GROOVY'

// almuhra-release-signing
def almuhraKeyProps = new Properties()
almuhraKeyProps.load(new FileInputStream(rootProject.file("key.properties")))
android {
    signingConfigs {
        almuhraRelease {
            keyAlias almuhraKeyProps['keyAlias']
            keyPassword almuhraKeyProps['keyPassword']
            storeFile file(almuhraKeyProps['storeFile'])
            storePassword almuhraKeyProps['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.almuhraRelease
        }
    }
}
GROOVY
fi
echo "android_setup: release signing configured in $gradle"
