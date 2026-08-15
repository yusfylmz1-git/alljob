# R8 / ProGuard — İlanda Hizmet (release)
#
# NEDEN: `minifyEnabled true` kod küçültme + isim karartma yapar. Kazanç iki
# yönlü: APK/AAB küçülür ve derlenmiş kod tersine mühendisliğe daha dirençli
# olur. Ancak R8 "kullanılmıyor" sandığı sınıfları SİLER — yansımayla
# (reflection) çağrılan her şey burada korunmalıdır, yoksa hata YALNIZ release
# derlemede ve çoğu zaman çalışma anında ortaya çıkar.
#
# ⚠️ Bu dosyayı değiştirdikten sonra MUTLAKA gerçek release derlemesiyle test
# et (`flutter build appbundle --release` + cihaz). Debug derleme R8
# çalıştırmaz; buradaki bir hata debug'da ASLA görünmez.

# ── Flutter motoru ────────────────────────────────────────────────────────
# Gömülü Java katmanı JNI ile çağrılır; R8 çağrıyı göremez.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ── Firebase / Google Play Services ───────────────────────────────────────
# Firestore ve Auth model sınıfları yansımayla serileştirilir.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore POJO alan adlarını korur (karartılırsa alan adları bozulur).
-keepclassmembers class * {
  @com.google.firebase.firestore.PropertyName <fields>;
  @com.google.firebase.firestore.PropertyName <methods>;
}

# Crashlytics: yığın izlerinin okunabilir kalması için kaynak bilgisi şart.
# Bu olmadan Console'daki çökme raporları anlamsız satır numaraları gösterir.
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

# ── Play Billing (in_app_purchase) ────────────────────────────────────────
# PARA YOLU: burada bir sınıf silinirse satın alma sessizce çalışmaz.
-keep class com.android.billingclient.** { *; }
-keep interface com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# ── Play Core (uygulama içi güncelleme / bölünmüş APK) ────────────────────
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ── image_cropper / uCrop ─────────────────────────────────────────────────
# UCropActivity manifest'ten (yansıma) açılır; R8 referansı göremez.
-keep class com.yalantis.ucrop.** { *; }
-keep interface com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# ── flutter_local_notifications ───────────────────────────────────────────
# Alıcılar (receiver) manifest'ten adla çağrılır.
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# ── Kotlin / coroutines ───────────────────────────────────────────────────
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# ── Genel: yerel (native) çağrılar ────────────────────────────────────────
-keepclasseswithmembernames class * {
  native <methods>;
}

# Enum'ların values()/valueOf() metotları yansımayla çağrılır.
-keepclassmembers enum * {
  public static **[] values();
  public static ** valueOf(java.lang.String);
}

# Parcelable CREATOR alanları silinmemeli.
-keepclassmembers class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# ── Gürültü bastırma ──────────────────────────────────────────────────────
# javax.annotation vb. derleme zamanı bağımlılıkları çalışma anında yok.
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn com.google.errorprone.annotations.**
