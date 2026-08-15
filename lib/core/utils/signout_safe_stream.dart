import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Oturum kapanışında Firestore dinleyicilerinin **sahte çökme** üretmesini
/// engelleyen ortak sarmalayıcı.
///
/// ## Sorun
///
/// `users/{uid}/...` kapsamlı bir `snapshots()` dinleyicisi, çıkış anında bir
/// an eski uid ile canlı kalır. Firebase Auth oturumu düşürdüğü anda güvenlik
/// kuralı bu dinleyiciyi artık tanımaz ve akışa `permission-denied` **hatası**
/// yayılır.
///
/// Riverpod bu hatayı `AsyncError`'a çevirir; ekranlar hata görünümüne düşer.
/// Kullanıcı için görüntü: **"çıkış yaptım, uygulama dondu/çöktü"**. Oysa
/// hiçbir şey bozulmamıştır — oturum kapanmıştır ve yönlendirme zaten
/// gerçekleşecektir.
///
/// ## Çözüm
///
/// Yalnız `permission-denied` yakalanır ve akış **sessizce kapatılır**
/// (`onDone`). Diğer tüm hatalar (ağ, indeks eksik, iptal) olduğu gibi
/// yayılır — onlar gerçek hatalardır ve kullanıcı görmelidir.
///
/// ⚠️ Kullanıcıya (uid'e) bağlı YENİ bir `snapshots()` akışı eklersen bunu
/// çağır; yoksa çıkışta o ekran hata verir.
///
/// ```dart
/// return _col(uid).snapshots().map(...).signOutSafe('bildirimler', uid);
/// ```
extension SignOutSafeStream<T> on Stream<T> {
  /// [etiket] yalnız hata ayıklama çıktısında görünür (hangi akış kapandı).
  Stream<T> signOutSafe(String etiket, String uid) {
    return handleError(
      (Object e) {
        // Release'te sessiz: bu beklenen bir yaşam döngüsü olayı, hata değil.
        if (kDebugMode) {
          debugPrint('[$etiket] oturum kapandı, akış durduruldu ($uid): $e');
        }
      },
      test: isSignOutDenial,
    );
  }
}

/// Oturum kapanışında beklenen Firestore reddi mi?
///
/// Yalnız `permission-denied`. Ağ kopması (`unavailable`) veya eksik indeks
/// (`failed-precondition`) BURAYA GİRMEZ — onlar gerçek hatadır, yutulursa
/// kullanıcı boş ekrana bakar ve sebebini asla öğrenemez.
bool isSignOutDenial(dynamic e) =>
    e is FirebaseException && e.code == 'permission-denied';
