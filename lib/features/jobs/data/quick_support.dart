import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/job.dart';

/// Hızlı Destek (ayak işleri) — müşteri şablonları + usta tanıtım bayrağı.
///
/// İlan kategorisi: [kQuickSupportCategory].
/// Usta mesleği: [kOtherProfession] (gösterim: "Hızlı Destek").

const _kArtisanIntroSeen = 'quick_support_artisan_intro_v1';

/// Müşteri ilan formunda tek dokunuşla doldurulan örnekler.
class QuickSupportExample {
  const QuickSupportExample({
    required this.label,
    required this.title,
    required this.description,
  });

  final String label;
  final String title;
  final String description;
}

const kQuickSupportExamples = <QuickSupportExample>[
  QuickSupportExample(
    label: 'Market / bakkal',
    title: 'Marketten alışveriş yapılacak',
    description:
        'Yakındaki market veya bakkaldan listeye göre alışveriş yapılıp '
        'adrese getirilecek. (Örn. ekmek, su, sigara vb.)',
  ),
  QuickSupportExample(
    label: 'Yük / odun taşıma',
    title: 'Yük veya odun taşınacak',
    description:
        'Kısa mesafede yük, odun veya koli taşınacak. Kat / bahçe bilgisi '
        've yaklaşık ağırlık yazın.',
  ),
  QuickSupportExample(
    label: 'Koli indirme',
    title: 'Koli veya eşya katlar arası taşınacak',
    description:
        'Paket / koli merdiven veya asansörle taşınacak. Adet ve kat '
        'bilgisi ekleyin.',
  ),
  QuickSupportExample(
    label: 'Eczane / kargo',
    title: 'Eczane veya kargo noktasına gidiş',
    description:
        'Yakındaki eczane, kargo veya ATM için kısa gidiş-dönüş yardımı.',
  ),
  QuickSupportExample(
    label: 'Kısa ev yardımı',
    title: 'Kısa süreli ev içi ayak işi',
    description:
        'Sök-tak, taşı, yerleştir gibi 15–60 dk sürebilecek küçük yardımlar. '
        'Uzmanlık gerektiren işler için ilgili mesleği seçin.',
  ),
];

Future<bool> readQuickSupportArtisanIntroSeen() async {
  try {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kArtisanIntroSeen) ?? false;
  } catch (_) {
    return true; // hata → tekrar gösterme
  }
}

Future<void> markQuickSupportArtisanIntroSeen() async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kArtisanIntroSeen, true);
  } catch (_) {/* ignore */}
}
