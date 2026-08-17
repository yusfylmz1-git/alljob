import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Çok sayıda etiketi profilde **taşırmadan** gösteren çip grubu
/// (new.md madde 4).
///
/// Sorun: mağaza 10+ satış kategorisi seçtiğinde `Wrap` sayfayı aşağı doğru
/// şişiriyor, profilin geri kalanı (ürünler, bölgeler) ekranın dışına
/// itiliyordu. Kategori çeşitlenmesi 28'e çıkınca bu iyice belirginleşti.
///
/// Çözüm: ilk [maxVisible] çip gösterilir, kalanı "+N daha" rozetinin
/// arkasına saklanır. Rozete dokununca yerinde açılır/kapanır — ayrı sayfa
/// yok, kaydırma yok.
class CollapsibleChips extends StatefulWidget {
  const CollapsibleChips({
    super.key,
    required this.labels,
    this.maxVisible = 6,
    this.avatarBuilder,
  });

  /// Gösterilecek etiketler (kod değil, GÖRÜNEN ad).
  final List<String> labels;

  /// Daraltılmış hâlde görünen çip sayısı. Bu sayıyı 2'den az aşan liste
  /// zaten kısadır; "+1 daha" göstermek yerine hepsi açık çizilir.
  final int maxVisible;

  /// İsteğe bağlı çip ikonu (ör. bölge çipinde konum simgesi).
  final Widget Function(String label)? avatarBuilder;

  @override
  State<CollapsibleChips> createState() => _CollapsibleChipsState();
}

class _CollapsibleChipsState extends State<CollapsibleChips> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final tumu = widget.labels;

    // Eşiği yalnız 1 aşıyorsa daraltma kazanç sağlamaz: "+1 daha" rozeti
    // gizlediği çip kadar yer kaplar. Doğrudan hepsini çiz.
    final daraltilabilir = tumu.length > widget.maxVisible + 1;
    final gorunen = (!daraltilabilir || _expanded)
        ? tumu
        : tumu.take(widget.maxVisible).toList();
    final gizliSayi = tumu.length - gorunen.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final label in gorunen)
          Chip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            padding: EdgeInsets.zero,
            avatar: widget.avatarBuilder?.call(label),
            label: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (daraltilabilir)
          ActionChip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            padding: EdgeInsets.zero,
            backgroundColor: palette.primaryContainer,
            side: BorderSide.none,
            onPressed: () => setState(() => _expanded = !_expanded),
            label: Text(
              _expanded ? 'Daha az' : '+$gizliSayi daha',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.primary,
              ),
            ),
          ),
      ],
    );
  }
}
