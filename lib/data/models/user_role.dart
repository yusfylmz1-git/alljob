/// Kullanıcının arayüz MODU (tek hesap, çift rol sistemi).
///
/// Kayıtta herkes müşteri modunda başlar. "Hizmet Vermeye Başla" ile usta
/// profili açan kullanıcı (`AppUser.hasArtisanProfile`) istediği zaman
/// Müşteri Modu ⇄ Usta Modu arasında geçiş yapabilir; arayüz aktif moda göre
/// şekillenir. Eski kayıtlardaki kalıcı `role` alanı geriye dönük uyum için
/// bu enum'a eşlenir.
enum UserRole {
  customer('customer', 'Müşteri'),
  artisan('artisan', 'Usta');

  const UserRole(this.apiValue, this.labelTR);

  final String apiValue;
  final String labelTR;

  static UserRole? fromString(String? value) {
    for (final role in UserRole.values) {
      if (role.apiValue == value) return role;
    }
    return null;
  }
}
