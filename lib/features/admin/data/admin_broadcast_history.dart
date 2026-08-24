import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_audit_repository.dart';
import 'admin_providers.dart';

/// Gönderilmiş bir duyuru — denetim kaydından türetilir (2026-08-23).
///
/// Ayrı bir koleksiyon AÇILMADI: veri zaten `adminAuditLogs` içinde tam
/// olarak duruyor (hedef, alıcı sayısı, kim gönderdi, ne zaman). İkinci bir
/// yere yazmak aynı bilgiyi iki kopyada tutmak ve ikisinin ayrışması
/// demekti.
class BroadcastRecord {
  const BroadcastRecord({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.audience,
    required this.recipients,
    required this.pushSent,
    this.profession,
    this.province,
    this.scheduled = false,
  });

  final String id;
  final DateTime createdAt;
  final String title;

  /// `all` · `artisans` · `customers` · `profession` · `province` · `user`
  final String audience;

  final int recipients;
  final bool pushSent;
  final String? profession;
  final String? province;

  /// Zamanlanmış kampanya olarak mı gitti? (`campaign_sent`)
  final bool scheduled;

  /// Hedefin okunur hâli — kod değil, insan dili.
  String hedefTR(Map<String, String> meslekAdlari) => switch (audience) {
        'all' => 'Herkes',
        'artisans' => 'Ustalar',
        'customers' => 'Müşteriler',
        'profession' =>
          'Meslek: ${meslekAdlari[profession] ?? profession ?? '—'}',
        'province' => 'İl: ${province ?? '—'}',
        'user' => 'Tek kişi',
        _ => audience,
      };

  /// Denetim kaydından okur; duyuru kaydı değilse `null`.
  static BroadcastRecord? fromAudit(AuditEntry e) {
    const eylemler = {'broadcast_notification', 'campaign_sent'};
    if (!eylemler.contains(e.action)) return null;
    final a = e.after ?? const <String, dynamic>{};

    // İKİ FARKLI ŞEKİL (2026-08-23):
    //  * `broadcast_notification` → alanlar DÜZ (`recipients` kökte)
    //  * `campaign_sent` → sonuç İÇ İÇE (`result.recipients`)
    // İkisi de okunabilmeli, yoksa zamanlanmış kampanyalar listede
    // "0 kişi" görünürdü.
    final r = (a['result'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    return BroadcastRecord(
      id: e.id,
      createdAt: e.createdAt,
      title: (a['title'] as String?)?.trim().isNotEmpty == true
          ? a['title'] as String
          : '(başlıksız)',
      audience: (a['audience'] as String?) ?? '—',
      recipients: (a['recipients'] as num?)?.toInt() ??
          (r['recipients'] as num?)?.toInt() ??
          0,
      pushSent: a['sendPush'] == true ||
          a['pushAttempted'] == true ||
          r['pushOk'] == true,
      profession: (a['profession'] as String?)?.trim().isEmpty == true
          ? null
          : a['profession'] as String?,
      province: (a['province'] as String?)?.trim().isEmpty == true
          ? null
          : a['province'] as String?,
      scheduled: e.action == 'campaign_sent',
    );
  }
}

/// Son gönderilen duyurular.
///
/// ── NEDEN BELLEKTE FİLTRELENİYOR ──
///
/// Denetim sorgusu `action` filtresi desteklemiyor ve eklemek **yeni bir
/// bileşik indeks** demek (`action + createdAt`). Duyuru seyrek bir işlem;
/// son 200 kaydı çekip süzmek yeterli ve indeks maliyeti doğurmuyor.
///
/// Ödün: çok yoğun bir denetim gününde eski duyurular 200'ün dışında kalıp
/// listede görünmeyebilir. Yönetici o durumda Denetim sekmesine bakar.
final broadcastHistoryProvider =
    FutureProvider.autoDispose<List<BroadcastRecord>>((ref) async {
  final repo = ref.watch(adminAuditRepositoryProvider);
  final kayitlar = await repo.fetchPage(limit: 200);
  return kayitlar
      .map(BroadcastRecord.fromAudit)
      .whereType<BroadcastRecord>()
      .take(20)
      .toList(growable: false);
});
