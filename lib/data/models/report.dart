/// İçerik/kullanıcı şikayeti (UGC politikası — Play/App Store zorunluluğu).
/// Kayıtlar `reports` koleksiyonuna yazılır; YALNIZCA oluşturulabilir
/// (okuma/güncelleme kapalı — admin fazında custom claim ile açılacak).
library;

/// Şikayet edilen hedefin türü.
enum ReportTarget {
  message('message'),
  job('job'),
  user('user'),
  // Eleman modülü (UGC): "iş arıyorum" kartı ve işveren eleman ilanı.
  staffWorker('staffWorker'),
  staffNeed('staffNeed'),
  // Keşfet Ürünler (PRD-006).
  product('product');

  const ReportTarget(this.apiValue);
  final String apiValue;
}

/// Şikayet nedeni (TR etiketli; sheet'te radyo listesi olarak gösterilir).
enum ReportReason {
  spam('spam', 'Spam / rahatsız edici mesajlar'),
  harassment('harassment', 'Hakaret / taciz'),
  scam('scam', 'Dolandırıcılık şüphesi'),
  inappropriate('inappropriate', 'Uygunsuz içerik'),
  other('other', 'Diğer');

  const ReportReason(this.apiValue, this.labelTR);
  final String apiValue;
  final String labelTR;
}

/// Şikayet dökümanının deterministik ID'si: hedef başına kullanıcı başına
/// TEK kayıt (aynı hedefi tekrar şikayet etmek kaydı günceller, kuyruğu
/// şişirmez). Kural bu formatı doğrular.
String reportDocId({
  required ReportTarget target,
  required String targetId,
  required String reporterUid,
}) =>
    '${target.apiValue}_${targetId}__$reporterUid';

/// Mesaj şikayetinde `targetId` biçimi: `${chatId}_${msgId}`
/// (bkz. chat_screen.dart mesaj şikayeti akışı).
String messageReportTargetId({
  required String chatId,
  required String messageId,
}) =>
    '${chatId}_$messageId';

/// [messageReportTargetId] biçiminden mesaj kimliğini çıkarır.
///
/// `split('_')` KULLANILMAZ: hem chatId hem msgId alt çizgi içerebilir
/// (chat id'leri `chat_{uid}__{uid}` kalıbında) — önek soyulur.
/// Biçim uymuyorsa null (çağıran reddetmeli).
///
/// CF paritesi: functions/index.js `adminModerateMessage`.
String? messageIdFromReportTarget({
  required String chatId,
  required String targetId,
}) {
  if (chatId.isEmpty || targetId.isEmpty) return null;
  final prefix = '${chatId}_';
  if (!targetId.startsWith(prefix)) return null;
  final id = targetId.substring(prefix.length);
  return id.isEmpty ? null : id;
}
