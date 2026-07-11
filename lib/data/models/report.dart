/// İçerik/kullanıcı şikayeti (UGC politikası — Play/App Store zorunluluğu).
/// Kayıtlar `reports` koleksiyonuna yazılır; YALNIZCA oluşturulabilir
/// (okuma/güncelleme kapalı — admin fazında custom claim ile açılacak).
library;

/// Şikayet edilen hedefin türü.
enum ReportTarget {
  message('message'),
  job('job'),
  user('user');

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
