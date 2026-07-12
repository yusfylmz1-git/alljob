import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/user_role.dart';
import '../../notifications/data/push_service.dart';
import '../data/auth_repository.dart';
import '../data/firebase_auth_repository.dart';
import '../data/mock_auth_repository.dart';

/// Aktif kimlik doğrulama sağlayıcısı. Backend seçimi tek yerden:
/// [useFirebaseBackend] (bkz. lib/core/config/backend_config.dart).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (useFirebaseBackend) return FirebaseAuthRepository();
  final repo = MockAuthRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Mevcut oturum durumu (null = oturum yok). Router bunu dinler.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Oturum açmış kullanıcıyı senkron okumak için kısayol.
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

/// Kimlik doğrulama eylemlerini (kayıt/giriş/çıkış) yürüten ve
/// onların yükleme/hata durumunu tutan controller.
/// UI bu controller'ı dinleyerek butonları kilitler ve hata gösterir.
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.register(
        displayName: displayName,
        email: email,
        password: password,
      );
    });
    return !state.hasError;
  }

  Future<bool> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.login(email: email, password: password);
    });
    return !state.hasError;
  }

  /// Google ile giriş (#3). Yeni kullanıcı düz kullanıcı (müşteri modu) açılır.
  Future<bool> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.signInWithGoogle();
    });
    return !state.hasError;
  }

  /// Profil > "Hizmet Vermeye Başla": usta profili açar + usta moduna geçer.
  Future<bool> becomeArtisan() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.becomeArtisan());
    return !state.hasError;
  }

  /// Müşteri Modu ⇄ Usta Modu geçişi.
  Future<bool> setActiveMode(UserRole mode) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.setActiveMode(mode));
    return !state.hasError;
  }

  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.sendPasswordReset(email));
    return !state.hasError;
  }

  /// E-posta doğrulama bağlantısını (yeniden) gönderir.
  Future<bool> sendEmailVerification() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.sendEmailVerification());
    return !state.hasError;
  }

  /// Doğrulama durumunu sunucudan tazeler; doğrulandıysa true.
  /// Hata durumunda null (UI "kontrol edilemedi" gösterir).
  Future<bool?> checkEmailVerified() async {
    state = const AsyncLoading();
    bool? verified;
    state = await AsyncValue.guard(() async {
      verified = await _repo.refreshEmailVerified();
    });
    return state.hasError ? null : verified;
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    // Çıkıştan ÖNCE bu cihazın FCM token'ını kullanıcının dizisinden çıkar
    // (uid oturum kapanınca kaybolur). Başka hesap bu cihaza bildirim almasın.
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid != null) {
      await ref.read(pushServiceProvider).unregisterFor(uid);
    }
    state = await AsyncValue.guard(() => _repo.signOut());
  }

  /// Hesabı KALICI olarak siler (onayı UI alır). Başarılıysa true; oturum
  /// repo tarafında kapanır (auth akışı null yayınlar, router yönlendirir).
  Future<bool> deleteAccount() async {
    state = const AsyncLoading();
    // Cihaz token'ını düşürmeyi dene — users dökümanı sunucuda zaten
    // silinecek, bu yalnızca cihaz tarafındaki token'ı geçersiz kılar.
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid != null) {
      await ref.read(pushServiceProvider).unregisterFor(uid);
    }
    state = await AsyncValue.guard(() => _repo.deleteAccount());
    return !state.hasError;
  }

  /// Yönetici erişimini etkinleştirir (yalnız izinli e-postalar). Başarıda
  /// kullanıcı yönetici olur ve auth akışına yansır. Şimdi yönetici mi döndürür;
  /// hata TR mesajlı [AuthException] olarak yeniden fırlatılır (UI gösterir).
  Future<bool> claimAdminAccess() async {
    return _repo.claimAdminAccess();
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
