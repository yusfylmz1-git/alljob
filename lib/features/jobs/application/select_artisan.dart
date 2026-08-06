import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/job.dart';
import '../../../data/models/offer.dart';
import '../../chat/data/chat_providers.dart';
import '../data/job_providers.dart';

/// Usta seçimi — İKİ giriş noktasının ortak mantığı.
///
/// Çağıranlar: ilan detayındaki "İlgilenen Ustalar" kartı ve sohbet ekranındaki
/// "Ustayı Seç" şeridi. İkisi de aynı sohbete bağlanır: `chatId`
/// `chatIdFor(müşteri, usta)` ile üretilir, ilandan TÜREMEZ.

/// Ustayı bu iş için seçer: onay diyaloğu → sohbeti hazırla → `selectOffer`.
///
/// [openChatAfter] sohbet ekranından çağrılırken `false` verilir (kullanıcı
/// zaten oradadır; üstüne aynı sohbeti bir daha push etmek geri tuşunu bozar).
///
/// Dönüş: seçim yapıldıysa `true`, kullanıcı vazgeçtiyse / hata olduysa `false`.
Future<bool> selectArtisanForJob(
  BuildContext context,
  WidgetRef ref, {
  required Job job,
  required String artisanId,
  required String artisanName,
  String? artisanPhotoUrl,
  bool openChatAfter = true,
}) async {
  // Başlık diyalogda ZORUNLU: sohbet şeridinde birden çok ilan listelenebilir
  // (aynı çift tek sohbeti paylaşır) — hangi işin kapandığı net olmalı.
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Ustayı seç'),
      content: Text(
          '"${job.title}" işi için $artisanName ustasını seçmek istiyor '
          'musunuz? Bu işlem ilanı kapatır ve diğer ustalar bilgilendirilir.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ustayı Seç')),
      ],
    ),
  );
  if (confirmed != true) return false;

  final String chatId;
  try {
    // Sohbet önce hazırlanır: `selectOffer` chatId'yi ilana yazar.
    chatId = await ref.read(chatRepositoryProvider).startChat(
          customerUid: job.customerId,
          customerName: job.customerName,
          customerPhotoUrl: job.customerPhotoUrl,
          artisanUid: artisanId,
          artisanName: artisanName,
          artisanPhotoUrl: artisanPhotoUrl,
          jobId: job.jobId,
          jobTitle: job.title,
        );
    // Teklif ID'si deterministik (jobId__artisanId) — listedeki kartla aynı.
    await ref.read(jobRepositoryProvider).selectOffer(
          jobId: job.jobId,
          offerId: Offer.idFor(job.jobId, artisanId),
          artisanId: artisanId,
          customerId: job.customerId,
          chatId: chatId,
        );
    // Sohbeti ustaya AÇ. Müşteri hiç mesaj yazmadan doğrudan işi verebilir;
    // o durumda `customerStarted` false kalır ve seçilen usta kendi işinin
    // sohbetinde "İletişimi müşteri başlatır" şeridinde kilitli kalırdı —
    // değerlendirme aşamasına kadar süren çıkmaz buydu. İşi vermek zaten
    // iletişimi başlatmaktan güçlü bir niyettir.
    //
    // Seçim BAŞARILI olduktan sonra ve ayrı try içinde: bayrak yazılamazsa
    // (ağ/kural) seçimi geri almanın anlamı yok, usta ilk müşteri mesajıyla
    // yine açılır.
    try {
      await ref.read(chatRepositoryProvider).markCustomerStarted(chatId);
    } catch (_) {/* seçim geçerli; bayrak ilk mesajda yazılır */}
  } catch (_) {
    if (context.mounted) {
      context.showError('Usta seçilemedi, lütfen tekrar deneyin.');
    }
    return false;
  }
  if (!context.mounted) return true;
  context.showSuccess('Usta seçildi.');
  if (openChatAfter) context.push(RoutePaths.chatThread(chatId));
  return true;
}

/// Bu ilan için ustanın seçilebilir olup olmadığı.
///
/// Sohbet artık ilan bazlı olduğundan (`chat_{müşteri}__{usta}__{jobId}`)
/// hangi işin konuşulduğu kesindir; liste süzmeye gerek kalmaz. Süresi dolmuş
/// ilanı `effectiveStatus` eler — durum alanı `open` kalsa bile kural
/// `open → workerSelected` geçişini süre dolduktan sonra reddeder.
bool canSelectArtisanFor(Job job) => job.effectiveStatus == JobStatus.open;
