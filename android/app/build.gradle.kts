import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Play yükleme anahtarı: android/key.properties VARSA release gerçek anahtarla
// imzalanır; yoksa debug'a düşer (keystore kurulana dek `flutter run --release`
// çalışsın). key.properties + *.jks gitignore'da — repoya asla girmez.
// Kurulum adımları: ILERLEME_NOTLARI.md Oturum 64.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.sepettehizmet.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications (Takip Merkezi Faz 2) core library
        // desugaring gerektirir (java.time vb. eski API'lerde).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Play Store'daki KALICI kimlik — ilk yüklemeden sonra ASLA değişemez.
        // Marka "Sepette Hizmet" olduğundan yayın ÖNCESİ güncellendi
        // (önceki: com.ustasindan.app, ondan önce: com.ustacepte.usta_cepte).
        // Her değişiklik Firebase'de YENİ Android app kaydı + yeni
        // google-services.json ister.
        applicationId = "com.sepettehizmet.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // minSdk 24: başlangıçta ARCore (kaldırılan Usta Çantası) gereğiydi.
        // AR gitti ama sınır DÜŞÜRÜLMEDİ — Firebase/Play hizmetleri zaten
        // 23+ istiyor ve 21-23 aralığı için kazanç yok, test yükü var.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // key.properties yoksa debug imza (yalnız yerel deneme).
            // Play'e YÜKLEME için keystore şart — debug imzalı AAB reddedilir.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
