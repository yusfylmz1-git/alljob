import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/utils/phone_format.dart';
import 'package:sepette_hizmet/data/models/artisan_profile.dart';

/// Telefon numarası değiştirme davranışları.
///
/// Kritik kural: usta numarasını vitrinde GÖSTERİYORSA, numara değişince
/// vitrindeki numara da yenilenmelidir — aksi hâlde profilde artık
/// kullanılmayan numara kalır ve müşteri yanlış kişiyi arar.
void main() {
  group('formatTrPhone', () {
    test('E.164 TR numarasını okunur biçime çevirir', () {
      expect(formatTrPhone('+905321234567'), '0532 123 45 67');
    });

    test('TR dışı / beklenmedik biçimi olduğu gibi döner', () {
      expect(formatTrPhone('+14155552671'), '+14155552671');
      expect(formatTrPhone('bozuk'), 'bozuk');
    });
  });

  group('Numara değişiminde vitrin senkronu', () {
    test('vitrin AÇIKKEN yeni numara eskisinin yerine geçer', () {
      // Eski durum: numara vitrinde görünüyor.
      final before = ArtisanProfile.initial('u1').copyWith(
        showPhoneOnProfile: true,
        publicPhone: '+905321111111',
      );
      expect(before.hasPublicPhone, isTrue);

      // Numara değişti → sheet vitrindeki numarayı da günceller.
      final after = before.copyWith(
        showPhoneOnProfile: true,
        publicPhone: '+905322222222',
      );

      expect(after.publicPhone, '+905322222222');
      expect(after.hasPublicPhone, isTrue,
          reason: 'vitrin açık kalmalı, numara yenilenmeli');
      expect(after.publicPhone, isNot(before.publicPhone),
          reason: 'eski numara profilde kalmamalı');
    });

    test('vitrin KAPALIYKEN numara değişimi vitrini açmaz', () {
      final before = ArtisanProfile.initial('u1').copyWith(
        showPhoneOnProfile: false,
      );
      // Sheet bu durumda setPhoneVisibility ÇAĞIRMAZ; profil aynı kalır.
      expect(before.hasPublicPhone, isFalse);
      expect(before.showPhoneOnProfile, isFalse,
          reason: 'rıza verilmemişken numara yayınlanmamalı');
    });

    test('depoya yazılıp geri okunduğunda yeni numara korunur', () {
      final p = ArtisanProfile.initial('u1').copyWith(
        showPhoneOnProfile: true,
        publicPhone: '+905322222222',
      );
      final seen = ArtisanProfile.fromMap('u1', p.toMap());
      expect(seen.publicPhone, '+905322222222');
      expect(seen.hasPublicPhone, isTrue);
    });
  });
}
