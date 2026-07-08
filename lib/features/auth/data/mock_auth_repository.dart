import 'dart:async';

import '../../../data/models/app_user.dart';
import '../../../data/models/user_role.dart';
import 'auth_repository.dart';

/// Bellek içi (in-memory) kimlik doğrulama. Firebase bağlanana kadar
/// uygulamanın uçtan uca çalışmasını sağlar. Oturum uygulama kapanınca silinir.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository() {
    // Geliştirme/test için hazır demo hesaplar.
    _seed('musteri@test.com', '123456', 'Test Müşteri');
    _seed('usta@test.com', '123456', 'Ahmet Usta', artisan: true);
  }

  final _controller = StreamController<AppUser?>.broadcast();
  final Map<String, _Account> _accounts = {}; // key: email (lowercase)
  AppUser? _current;

  void _seed(String email, String password, String name,
      {bool artisan = false}) {
    final uid = 'mock_${_accounts.length + 1}';
    _accounts[email.toLowerCase()] = _Account(
      password: password,
      user: AppUser(
        uid: uid,
        displayName: name,
        email: email,
        hasArtisanProfile: artisan,
        activeMode: artisan ? UserRole.artisan : UserRole.customer,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  AppUser? get currentUser => _current;

  void _emit(AppUser? user) {
    _current = user;
    _controller.add(user);
  }

  // Gerçekçi his için küçük bir gecikme.
  Future<void> _delay() => Future.delayed(const Duration(milliseconds: 600));

  @override
  Future<AppUser> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    await _delay();
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) throw AuthException.emailInUse;
    if (password.length < 6) throw AuthException.weakPassword;

    final user = AppUser(
      uid: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      displayName: displayName.trim(),
      email: email.trim(),
      createdAt: DateTime.now(),
    );
    _accounts[key] = _Account(password: password, user: user);
    _emit(user);
    return user;
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    await _delay();
    final account = _accounts[email.trim().toLowerCase()];
    if (account == null) throw AuthException.userNotFound;
    if (account.password != password) throw AuthException.wrongPassword;
    _emit(account.user);
    return account.user;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    await _delay();
    // Mock: sabit bir Google hesabını canlandırır; ilk girişte oluşturulur.
    const email = 'google@test.com';
    final existing = _accounts[email];
    if (existing != null) {
      _emit(existing.user);
      return existing.user;
    }
    final user = AppUser(
      uid: 'mock_google_${DateTime.now().millisecondsSinceEpoch}',
      displayName: 'Google Kullanıcısı',
      email: email,
      createdAt: DateTime.now(),
    );
    _accounts[email] = _Account(password: '-', user: user);
    _emit(user);
    return user;
  }

  @override
  Future<AppUser> becomeArtisan() async {
    await _delay();
    final user = _current;
    if (user == null) throw AuthException.notSignedIn;
    final updated = user.copyWith(
      hasArtisanProfile: true,
      activeMode: UserRole.artisan,
    );
    _store(updated);
    _emit(updated);
    return updated;
  }

  @override
  Future<AppUser> setActiveMode(UserRole mode) async {
    final user = _current;
    if (user == null) throw AuthException.notSignedIn;
    if (mode == UserRole.artisan && !user.hasArtisanProfile) {
      throw AuthException.noArtisanProfile;
    }
    final updated = user.copyWith(activeMode: mode);
    _store(updated);
    _emit(updated);
    return updated;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _delay();
    // Mock: gerçek e-posta gönderilmez. Güvenlik için hesap olmasa da hata vermez.
  }

  @override
  Future<void> updateUserProfile({
    String? displayName,
    String? profilePhotoUrl,
  }) async {
    await _delay();
    final user = _current;
    if (user == null) return;
    final updated = user.copyWith(
      displayName: displayName,
      profilePhotoUrl: profilePhotoUrl,
    );
    _store(updated);
    _emit(updated);
  }

  /// Hesap deposundaki kaydı günceller (yeniden girişte korunur).
  void _store(AppUser updated) {
    final key = updated.email.toLowerCase();
    final account = _accounts[key];
    if (account != null) {
      _accounts[key] = _Account(password: account.password, user: updated);
    }
  }

  @override
  Future<void> signOut() async {
    _emit(null);
  }

  void dispose() => _controller.close();
}

class _Account {
  _Account({required this.password, required this.user});
  final String password;
  final AppUser user;
}
