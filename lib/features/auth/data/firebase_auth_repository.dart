import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/user_role.dart';
import 'auth_repository.dart';

/// Firebase Authentication + Firestore `users` koleksiyonu ile çalışan
/// [AuthRepository]. Rol ve profil bilgisi `users/{uid}` dökümanında tutulur.
///
/// Aktifleştirmek için: `flutterfire configure` + `useFirebaseBackend = true`.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AppUser? _cached;

  /// users dökümanı uygulama içinden değişince (mod geçişi, usta profili
  /// açma) auth akışına elle yayın yapılır — `userChanges()` yalnızca Auth
  /// tarafındaki değişikliklerde tetiklenir, Firestore'u görmez.
  final _manualUpdates = StreamController<AppUser?>.broadcast();

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Stream<AppUser?> authStateChanges() {
    final fromAuth = _auth.userChanges().asyncMap((fbUser) async {
      if (fbUser == null) {
        _cached = null;
        return null;
      }
      final user = await _loadOrCreate(fbUser);
      _cached = user;
      return user;
    });

    // Auth olayları + uygulama içi kullanıcı güncellemeleri tek akışta.
    late StreamController<AppUser?> ctrl;
    StreamSubscription<AppUser?>? authSub;
    StreamSubscription<AppUser?>? manualSub;
    ctrl = StreamController<AppUser?>(
      onListen: () {
        authSub = fromAuth.listen(ctrl.add, onError: ctrl.addError);
        manualSub = _manualUpdates.stream.listen(ctrl.add);
      },
      onCancel: () async {
        await authSub?.cancel();
        await manualSub?.cancel();
      },
    );
    return ctrl.stream;
  }

  /// `users/{uid}` dökümanını okur; yoksa (ör. yalnızca Auth'ta olan hesap için)
  /// Auth bilgisinden minimal bir müşteri dökümanı oluşturur.
  Future<AppUser> _loadOrCreate(fb.User fbUser) async {
    // Yönetici yetkisi Auth CUSTOM CLAIM'inden okunur (Firestore'a yazılmaz);
    // token okunamazsa admin DEĞİL kabul edilir (fail-safe).
    final isAdmin = await _readAdminClaim(fbUser);
    final snap = await _userDoc(fbUser.uid).get();
    if (snap.exists && snap.data() != null) {
      // emailVerified'ın kaynağı Firestore değil Auth'tur (bkz. AppUser).
      return AppUser.fromMap(fbUser.uid, snap.data()!)
          .copyWith(emailVerified: fbUser.emailVerified, isAdmin: isAdmin);
    }
    final fresh = AppUser(
      uid: fbUser.uid,
      displayName: fbUser.displayName ?? '',
      email: fbUser.email ?? '',
      createdAt: DateTime.now(),
      profilePhotoUrl: fbUser.photoURL,
      emailVerified: fbUser.emailVerified,
      isAdmin: isAdmin,
    );
    await _userDoc(fbUser.uid).set(fresh.toMap());
    return fresh;
  }

  /// Auth token'ından `admin` custom claim'ini okur (yoksa/hatada false).
  Future<bool> _readAdminClaim(fb.User fbUser) async {
    try {
      final result = await fbUser.getIdTokenResult();
      return result.claims?['admin'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  AppUser? get currentUser => _cached;

  @override
  Future<AppUser> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      final fbUser = cred.user!;
      await fbUser.updateDisplayName(displayName.trim());
      // Doğrulama bağlantısı otomatik gönderilir; başarısızlığı kayıt
      // akışını BOZMAZ (profilden yeniden gönderilebilir).
      try {
        await fbUser.sendEmailVerification();
      } catch (_) {/* profildeki "yeniden gönder" telafi eder */}
      final user = AppUser(
        uid: fbUser.uid,
        displayName: displayName.trim(),
        email: email.trim(),
        createdAt: DateTime.now(),
        profilePhotoUrl: fbUser.photoURL,
      );
      await _userDoc(fbUser.uid).set(user.toMap());
      _cached = user;
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      final user = await _loadOrCreate(cred.user!);
      _cached = user;
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  /// Firebase konsolundaki WEB OAuth client ID'si (google-services.json →
  /// oauth_client[client_type=3]). Android'de kimlik jetonu (idToken) almak
  /// için zorunludur; gizli bilgi değildir.
  static const _webClientId =
      '839781526307-igop85vu9fqtrsvs5o853hp5alekulqb.apps.googleusercontent.com';

  Future<void>? _googleInit;

  /// Android/iOS: yerel Google hesap seçici (google_sign_in) → Firebase
  /// credential. Tarayıcı tabanlı akış ("missing initial state" hatası)
  /// yerine kullanılır.
  Future<fb.UserCredential> _googleNative() async {
    final google = GoogleSignIn.instance;
    _googleInit ??= google.initialize(serverClientId: _webClientId);
    await _googleInit;
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    return _auth.signInWithCredential(
      fb.GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      // Web: popup; mobil: yerel Google hesap seçici.
      final cred = kIsWeb
          ? await _auth.signInWithPopup(fb.GoogleAuthProvider())
          : await _googleNative();
      final fbUser = cred.user!;

      // İlk girişse düz kullanıcı dökümanı oluştur; mevcutsa kaydı koru.
      final user = await _loadOrCreate(fbUser);
      _cached = user;
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw _map(e);
    } on GoogleSignInException catch (e) {
      // Yerel hesap seçici hataları (kullanıcı vazgeçti vb.).
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw AuthException.cancelled;
      }
      throw AuthException('Google girişi başarısız (${e.code.name}).');
    }
  }

  @override
  Future<AppUser> becomeArtisan() async {
    final user = _cached;
    if (user == null) throw AuthException.notSignedIn;
    final updated = user.copyWith(
      hasArtisanProfile: true,
      activeMode: UserRole.artisan,
    );
    await _userDoc(user.uid).set({
      'hasArtisanProfile': true,
      'activeMode': UserRole.artisan.apiValue,
      'role': UserRole.artisan.apiValue,
    }, SetOptions(merge: true));
    _cached = updated;
    _manualUpdates.add(updated);
    return updated;
  }

  @override
  Future<AppUser> setActiveMode(UserRole mode) async {
    final user = _cached;
    if (user == null) throw AuthException.notSignedIn;
    if (mode == UserRole.artisan && !user.hasArtisanProfile) {
      throw AuthException.noArtisanProfile;
    }
    final updated = user.copyWith(activeMode: mode);
    await _userDoc(user.uid).set({
      'activeMode': mode.apiValue,
      'role': mode.apiValue,
    }, SetOptions(merge: true));
    _cached = updated;
    _manualUpdates.add(updated);
    return updated;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) throw AuthException.notSignedIn;
    try {
      await fbUser.sendEmailVerification();
    } on fb.FirebaseAuthException catch (e) {
      // Firebase art arda gönderimi hız sınırına takar.
      if (e.code == 'too-many-requests') {
        throw const AuthException(
            'Çok sık denediniz. Bir süre sonra tekrar deneyin.');
      }
      throw _map(e);
    }
  }

  @override
  Future<bool> refreshEmailVerified() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) throw AuthException.notSignedIn;
    await fbUser.reload();
    final verified = _auth.currentUser?.emailVerified ?? false;
    // userChanges() reload sonrası her zaman yayın yapmayabilir — UI'ın
    // anında yenilenmesi için güncel kullanıcıyı elle de yayınla.
    final cached = _cached;
    if (cached != null && cached.emailVerified != verified) {
      _cached = cached.copyWith(emailVerified: verified);
      _manualUpdates.add(_cached);
    }
    return verified;
  }

  @override
  Future<AppUser> setPhoneVerified(String phoneE164) async {
    final user = _cached;
    final fbUser = _auth.currentUser;
    if (user == null || fbUser == null) throw AuthException.notSignedIn;

    // Kural `token.phone_number` ister; telefon bağlandıktan sonra jetonu
    // tazeleyerek claim'in kesin olarak gelmesini sağlarız.
    await fbUser.getIdToken(true);

    // Herkese açık işaret.
    await _userDoc(user.uid)
        .set({'phoneVerified': true}, SetOptions(merge: true));
    // Hassas numara yalnızca sahibin okuyabildiği özel alt-koleksiyonda.
    await _userDoc(user.uid).collection('private').doc('contact').set({
      'phoneNumber': phoneE164,
      'verifiedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final updated = user.copyWith(phoneVerified: true, phoneNumber: phoneE164);
    _cached = updated;
    _manualUpdates.add(updated);
    return updated;
  }

  @override
  Future<void> updateUserProfile({
    String? displayName,
    String? profilePhotoUrl,
  }) async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return;
    if (displayName != null) await fbUser.updateDisplayName(displayName);
    if (profilePhotoUrl != null) await fbUser.updatePhotoURL(profilePhotoUrl);
    final data = <String, dynamic>{};
    if (displayName != null) data['displayName'] = displayName;
    if (profilePhotoUrl != null) data['profilePhotoURL'] = profilePhotoUrl;
    if (data.isNotEmpty) {
      await _userDoc(fbUser.uid).set(data, SetOptions(merge: true));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) throw AuthException.notSignedIn;
    try {
      // Sunucu tarafı temizlik: Firestore + Storage + Auth kaydı
      // (functions/index.js `deleteAccount`; bölge CF'lerle aynı).
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('deleteAccount',
              options: HttpsCallableOptions(
                  timeout: const Duration(minutes: 3)))
          .call<Map<String, dynamic>>();
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(
          'Hesap silinemedi (${e.code}). Bağlantınızı kontrol edip '
          'tekrar deneyin.');
    }
    // Auth kaydı sunucuda silindi; yerel oturum verisini temizle.
    await _auth.signOut();
  }

  @override
  Future<bool> claimAdminAccess() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) throw AuthException.notSignedIn;
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('claimAdminAccess')
          .call<Map<String, dynamic>>();
    } on FirebaseFunctionsException catch (e) {
      // İzin listesinde değilse sunucu 'permission-denied' döndürür.
      if (e.code == 'permission-denied') {
        throw const AuthException('Bu hesap yönetici yetkisine sahip değil.');
      }
      throw AuthException(
          'Yönetici erişimi etkinleştirilemedi (${e.code}). Bağlantınızı '
          'kontrol edip tekrar deneyin.');
    }
    // Claim yazıldı → token'ı zorla tazele ve akışa yansıt.
    await fbUser.getIdToken(true);
    final isAdmin = await _readAdminClaim(fbUser);
    if (_cached != null && _cached!.isAdmin != isAdmin) {
      _cached = _cached!.copyWith(isAdmin: isAdmin);
      _manualUpdates.add(_cached);
    }
    return isAdmin;
  }

  /// Firebase hata kodlarını Türkçe [AuthException]'a çevirir.
  AuthException _map(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return AuthException.emailInUse;
      case 'user-not-found':
        return AuthException.userNotFound;
      case 'wrong-password':
      case 'invalid-credential':
        return AuthException.wrongPassword;
      case 'weak-password':
        return AuthException.weakPassword;
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'user-cancelled':
      case 'web-context-canceled':
        return AuthException.cancelled;
      case 'operation-not-allowed':
        return AuthException.providerDisabled;
      case 'unauthorized-domain':
        return AuthException.unauthorizedDomain;
      default:
        // Bilinmeyen kodu mesajda göster — teşhisi kolaylaştırır.
        return AuthException(
            'Giriş başarısız (${e.code}). Lütfen tekrar deneyin.');
    }
  }
}
