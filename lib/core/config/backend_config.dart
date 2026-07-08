/// Backend seçimi — mock (bellek içi) ile Firebase arasında TEK anahtar.
///
/// `false` (varsayılan): uygulama bellek içi mock repolarla çalışır; Firebase
/// kurulumu gerekmez. `true`: providerlar Firebase implementasyonlarına geçer
/// (Auth/Firestore/Storage). Önce `flutterfire configure` ile
/// `firebase_options.dart` üretilmiş ve `main.dart`'ta `Firebase.initializeApp`
/// çağrılmış olmalıdır. Ayrıntılar: `FIREBASE_KURULUM.md`.
const bool useFirebaseBackend = true;

/// Firebase Cloud Storage kullanımı. Storage, Blaze (kartlı) plan gerektirir.
/// Kart bağlamadan Auth+Firestore ile çalışmak için bunu `false` bırak: foto
/// yükleme bellek içi mock ile yapılır (yalnızca o oturum boyunca görünür).
/// Blaze'i açıp Storage'ı etkinleştirince `true` yap → gerçek kalıcı URL'ler.
/// Yalnızca [useFirebaseBackend] true iken anlamlıdır.
///
/// AÇIK (Oturum 20, 2026-07-08): kullanıcı Blaze planını + Storage bucket'ını
/// (`gs://alljob1.firebasestorage.app`) kurdu. Kurallar `storage.rules`'da;
/// deploy: `firebase deploy --only storage --project alljob1`.
const bool useFirebaseStorage = true;
