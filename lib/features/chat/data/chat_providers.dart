import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/models/chat.dart';
import '../../auth/application/auth_controller.dart';
import 'chat_repository.dart';
import 'firebase_chat_repository.dart';

/// Uygulama boyunca yaşayan tek sohbet deposu (auth değişince silinmez).
/// Backend seçimi [useFirebaseBackend] ile.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  if (useFirebaseBackend) return FirebaseChatRepository();
  final repo = MockChatRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Oturum açmış kullanıcının sohbet listesi (canlı).
final myThreadsProvider = StreamProvider<List<ChatThread>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(chatRepositoryProvider).watchThreads(user.uid);
});

/// Belirli bir sohbetin mesajları (canlı).
final messagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).watchMessages(chatId);
});

/// Oturum açmış kullanıcının tüm sohbetlerindeki toplam okunmamış mesaj sayısı.
/// Sohbet listesi akışı yeniden yayınlandıkça (yeni mesaj / okundu) tazelenir.
final totalUnreadProvider = Provider<int>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;
  final repo = ref.watch(chatRepositoryProvider);
  final threadsAsync = ref.watch(myThreadsProvider);
  return threadsAsync.maybeWhen(
    data: (threads) => threads.fold<int>(
        0, (sum, t) => sum + repo.unreadCount(chatId: t.id, uid: user.uid)),
    orElse: () => 0,
  );
});

/// Okunmamışları TARAFA göre ayırır (tek hesap, çift rol): kullanıcının usta
/// olduğu sohbetler "usta tarafı", müşteri olduğu sohbetler "müşteri tarafı".
final unreadBySideProvider = Provider<({int customer, int artisan})>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return (customer: 0, artisan: 0);
  final repo = ref.watch(chatRepositoryProvider);
  final threadsAsync = ref.watch(myThreadsProvider);
  return threadsAsync.maybeWhen(
    data: (threads) {
      var customer = 0, artisan = 0;
      for (final t in threads) {
        final n = repo.unreadCount(chatId: t.id, uid: user.uid);
        if (t.artisanUid == user.uid) {
          artisan += n;
        } else {
          customer += n;
        }
      }
      return (customer: customer, artisan: artisan);
    },
    orElse: () => (customer: 0, artisan: 0),
  );
});

/// Aktif modun KARŞISINA düşen okunmamışlar (çapraz mod rozeti): müşteri
/// modundayken usta tarafına mesaj gelirse ☰ menü düğmesinde kırmızı nokta ve
/// "Usta Moduna Geç" satırında rozet gösterilir (tersi de aynı). Usta profili
/// olmayan kullanıcı için her zaman 0.
final otherModeUnreadProvider = Provider<int>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.hasArtisanProfile) return 0;
  final bySide = ref.watch(unreadBySideProvider);
  return user.isArtisan ? bySide.customer : bySide.artisan;
});
