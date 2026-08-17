import 'dart:async';

import '../../../core/utils/validators.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/geo_models.dart';
import '../../../data/models/social_links.dart';
import '../../../data/models/user_role.dart';
import '../../admin/data/admin_config.dart';
import 'auth_repository.dart';

/// Bellek içi (in-memory) kimlik doğrulama. Firebase bağlanana kadar
/// uygulamanın uçtan uca çalışmasını sağlar. Oturum uygulama kapanınca silinir.
class MockAuthRepository implements AuthRepository {
  /// [publicUserResolver]: oturum DIŞINDAKİ uid'ler için görüntülenebilir
  /// kullanıcı döndürür (tipik olarak `MockDatabase.publicUser`).
  ///
  /// Neden var: Firestore'da `users/{uid}` HERKESE AÇIK okunur (CLAUDE.md
  /// kural 5), ama mock yalnız oturumdaki kullanıcıyı biliyordu. Bu bir
  /// parite açığıydı — "başkasının profili" akışları (sohbet başlığı, ürün
  /// satıcısı, herkese açık profil) bellek içi doğru çalışmıyordu.
  /// Verilmezse eski iskelet davranışı korunur, mevcut testler etkilenmez.
  MockAuthRepository({AppUser? Function(String uid)? publicUserResolver})
      : _resolvePublic = publicUserResolver {
    // Geliştirme/test için hazır demo hesaplar.
    _seed('musteri@test.com', '123456', 'Test Müşteri');
    _seed('usta@test.com', '123456', 'Ahmet Usta', artisan: true);
  }

  final _controller = StreamController<AppUser?>.broadcast();
  final Map<String, _Account> _accounts = {}; // key: email (lowercase)
  final AppUser? Function(String uid)? _resolvePublic;
  AppUser? _current;

  void _seed(
    String email,
    String password,
    String name, {
    bool artisan = false,
  }) {
    final uid = 'mock_${_accounts.length + 1}';
    _accounts[email.toLowerCase()] = _Account(
      password: password,
      user: AppUser(
        uid: uid,
        displayName: name,
        email: email,
        hasArtisanProfile: artisan,
        activeMode: artisan ? UserRole.artisan : UserRole.customer,
        emailVerified: true, // demo hesaplar doğrulanmış görünür
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
    final name = Validators.normalizeDisplayName(displayName);
    final nameErr = Validators.displayName(name);
    if (nameErr != null) throw AuthException(nameErr);
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) throw AuthException.emailInUse;
    if (password.length < 6) throw AuthException.weakPassword;

    final user = AppUser(
      uid: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      displayName: name,
      email: email.trim(),
      createdAt: DateTime.now(),
    );
    _accounts[key] = _Account(password: password, user: user);
    // Firebase paritesi: kayıtta doğrulama e-postası otomatik "gönderilir".
    _verificationPending = true;
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
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _delay();
    final user = _current;
    if (user == null) throw AuthException.notSignedIn;
    final key = user.email.trim().toLowerCase();
    final account = _accounts[key];
    if (account == null) throw AuthException.noPasswordProvider;
    if (account.password != currentPassword) throw AuthException.wrongPassword;
    if (newPassword.trim().length < 6) throw AuthException.weakPassword;
    _accounts[key] = _Account(password: newPassword, user: account.user);
  }

  /// Test kancası: "kullanıcı e-postadaki bağlantıya tıkladı" simülasyonu.
  /// Gerçekte doğrulama Firebase Auth tarafında gerçekleşir; mock'ta bekleyen
  /// doğrulama [refreshEmailVerified] çağrılınca hesaba işlenir.
  bool _verificationPending = false;

  @override
  Future<void> sendEmailVerification() async {
    if (_current == null) throw AuthException.notSignedIn;
    await _delay();
    _verificationPending = true;
  }

  @override
  Future<bool> refreshEmailVerified() async {
    final user = _current;
    if (user == null) throw AuthException.notSignedIn;
    await _delay();
    if (_verificationPending && !user.emailVerified) {
      _verificationPending = false;
      final updated = user.copyWith(emailVerified: true);
      _store(updated);
      _emit(updated);
      return true;
    }
    return user.emailVerified;
  }

  @override
  Future<AppUser> setPhoneVerified(String phoneE164) async {
    await _delay();
    final user = _current;
    if (user == null) throw AuthException.notSignedIn;
    final updated = user.copyWith(phoneVerified: true, phoneNumber: phoneE164);
    _store(updated);
    _emit(updated);
    return updated;
  }

  @override
  Future<void> updateUserProfile({
    String? displayName,
    String? profilePhotoUrl,
    String? publicPhone,
    SocialLinks? socialLinks,
    String? aboutText,
    bool? hasShopProfile,
    List<String>? shopCategories,
    List<ServiceArea>? shopServiceAreas,
    bool? available,
  }) async {
    await _delay();
    final user = _current;
    if (user == null) return;
    String? name = displayName;
    if (displayName != null) {
      name = Validators.normalizeDisplayName(displayName);
      final nameErr = Validators.displayName(name);
      if (nameErr != null) throw AuthException(nameErr);
    }
    // KURAL PARİTESİ: `firestore.rules` → `providerFlagOk`. Mağaza profilini
    // AÇMAK doğrulanmış telefon ister; kapatmak ve zaten açık profili
    // güncellemek serbesttir. Mock bunu taklit etmezse istemci kapısındaki
    // bir gerileme yalnız canlıda patlar (CLAUDE.md kural 1).
    if (hasShopProfile == true &&
        !user.hasShopProfile &&
        !user.phoneVerified) {
      throw const AuthException(
        'Mağaza açmak için telefon doğrulaması gerekiyor.',
      );
    }
    // Firebase paritesi: boş dize = ALANI TEMİZLE (kural 1).
    final t = publicPhone?.trim();
    var updated = user.copyWith(
      displayName: name,
      profilePhotoUrl: profilePhotoUrl,
      publicPhone: (t == null || t.isEmpty) ? null : t,
      clearPublicPhone: t != null && t.isEmpty,
      socialLinks: socialLinks,
      aboutText: aboutText?.trim(),
      hasShopProfile: hasShopProfile,
      shopCategories: shopCategories,
      shopServiceAreas: shopServiceAreas,
      available: available,
    );
    // Firebase paritesi: ortak alanlardan biri yazıldığı an kayıt "göçmüş"
    // sayılır (orada `fromMap` alanın VARLIĞINA bakar). Bayrak taşınmazsa
    // mock'ta silinen bağlantı geri gelir, gerçek uygulamada gelmez.
    if (publicPhone != null || socialLinks != null || aboutText != null) {
      updated = updated.markOrtakAlanlarGocmus();
    }
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

  @override
  Future<AppUser?> fetchPublicUser(String uid) async {
    await _delay();
    final me = _current;
    if (me != null && me.uid == uid) return me;
    if (uid.trim().isEmpty) return null;
    // Rehber verilmişse başka kullanıcıları da çözer (Firestore'da users/{uid}
    // herkese açık okunur — bkz. kurucu notu).
    final resolved = _resolvePublic?.call(uid);
    if (resolved != null) return resolved;
    // Rehber yoksa/tanımıyorsa: gösterilebilir iskelet (ekran boş kalmasın).
    return AppUser(
      uid: uid,
      displayName: 'Kullanıcı',
      email: '',
      createdAt: DateTime.now(),
    );
  }

  @override
  Stream<AppUser?> watchPublicUser(String uid) {
    // Firebase paritesi: canlı akış. Mock'ta tek gerçek kaynak oturumdaki
    // kullanıcıdır; kendi uid'imiz için auth akışını izleriz ki müsaitlik
    // değişimi (users.available) anında yansısın — gerçek uygulamada da
    // öyle davranır.
    if (uid.trim().isEmpty) return Stream.value(null);
    return authStateChanges().asyncMap((u) {
      if (u != null && u.uid == uid) return u;
      return fetchPublicUser(uid);
    });
  }

  @override
  Future<void> deleteAccount() async {
    await _delay();
    final user = _current;
    if (user == null) throw AuthException.notSignedIn;
    // Hesap deposundan kalıcı silinir: aynı e-postayla giriş artık başarısız.
    _accounts.remove(user.email.toLowerCase());
    _emit(null);
  }

  @override
  Future<bool> claimAdminAccess() async {
    await _delay();
    final user = _current;
    if (user == null) throw AuthException.notSignedIn;
    // Sunucu paritesi: yalnızca izin listesindeki e-posta yönetici olabilir.
    if (!isBootstrapAdminEmail(user.email)) {
      throw const AuthException('Bu hesap yönetici yetkisine sahip değil.');
    }
    // _emit ayrıca _current'ı da günceller. Bootstrap her zaman superadmin.
    _emit(user.copyWith(isAdmin: true, adminRole: 'superadmin'));
    return true;
  }

  void dispose() => _controller.close();
}

class _Account {
  _Account({required this.password, required this.user});
  final String password;
  final AppUser user;
}
