import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// İş akışına özgü kısa sorumluluk reddi / güvenlik notu.
///
/// ## Neden akışa özgü
///
/// Kullanım Koşulları'ndaki genel metni kimse okumaz. Uyarı, kullanıcının
/// riskli kararı **verdiği anda** ve o karara **özgü** dille görünmelidir:
/// ürün satın alırken "önce görüp öyle öde", iş verirken "ödemeyi peşin
/// yapma" gibi. Aynı genel cümleyi her yere koymak uyarı körlüğü yaratır.
///
/// Kısa tutulur (1–2 cümle): uzun metin okunmaz ve ekranı boğar. Ayrıntı
/// için Kullanım Koşulları'na bakılır.
///
/// ⚠️ Yeni bir para/teslimat içeren akış eklersen [DisclaimerNote.forFlow]
/// içine kendi metnini ekle — genel bir cümleyle geçiştirme.
class DisclaimerNote extends StatelessWidget {
  const DisclaimerNote({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  /// Akış tipine göre hazır metin.
  factory DisclaimerNote.forFlow(DisclaimerFlow flow) => DisclaimerNote(
        text: flow.text,
        icon: flow.icon,
      );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.warningSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? Icons.info_outline_rounded,
            size: 18,
            color: palette.inkMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.inkMuted,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uyarı gerektiren akışlar. Her biri kendi riskini anlatır.
enum DisclaimerFlow {
  /// Ürün detayı — alıcı tarafı. En yüksek dolandırıcılık riski burada:
  /// ödeme ve teslimat platform dışında.
  urunSatinAlma,

  /// Ürün ekleme — satıcı tarafı. Mevzuat yükümlülüğü satıcıdadır.
  urunYayinlama,

  /// İlan verme — müşteri tarafı (iş yaptırma).
  ilanVerme,

  /// Usta seçimi / teklif kabulü.
  ustaSecimi;

  String get text => switch (this) {
        DisclaimerFlow.urunSatinAlma =>
          'Ödeme ve teslimat uygulama dışında, doğrudan satıcıyla yapılır. '
              'İlanda Hizmet satışın tarafı değildir ve ürünü garanti etmez. '
              'Peşin ödemeden önce ürünü görmeniz önerilir.',
        DisclaimerFlow.urunYayinlama =>
          'Ürün bilgilerinin doğruluğundan ve satışın mevzuata uygunluğundan '
              '(vergi, fatura, tüketici hakları) siz sorumlusunuz. Satışı '
              'yasak ürünler yayınlanamaz.',
        DisclaimerFlow.ilanVerme =>
          'İlanda Hizmet işin tarafı değildir. Anlaşma, ödeme ve işin '
              'yapılması sizinle usta arasındadır; ödemeyi iş tamamlanmadan '
              'peşin yapmamanız önerilir.',
        DisclaimerFlow.ustaSecimi =>
          'Ustanın yetkinliği, belgesi ve iş kalitesi İlanda Hizmet '
              'tarafından garanti edilmez. Anlaşmadan önce referans ve '
              'değerlendirmelere bakmanız önerilir.',
      };

  IconData get icon => switch (this) {
        DisclaimerFlow.urunSatinAlma => Icons.shopping_bag_outlined,
        DisclaimerFlow.urunYayinlama => Icons.gavel_outlined,
        DisclaimerFlow.ilanVerme => Icons.handshake_outlined,
        DisclaimerFlow.ustaSecimi => Icons.verified_user_outlined,
      };
}
