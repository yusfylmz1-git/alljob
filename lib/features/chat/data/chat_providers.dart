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
/// Yalnız Mesajlar ekranı (ve listeye bağlı UI) dinler — alt bar rozeti
/// [chatUnreadMetaProvider] kullanır; tüm thread snapshot'ı global tutulmaz.
/// Tek bir sohbeti CANLI izler (yoksa null).
///
/// `getThread` yalnız bellek önbelleğine bakar ve sohbet listesi hiç
/// açılmadıysa boş döner; bu provider doğrudan dokümanı dinler. İlan
/// detayından/bildirimden gelen derin bağlantılarda tek güvenilir kaynak.
final chatThreadProvider =
    StreamProvider.family<ChatThread?, String>((ref, chatId) {
  if (chatId.isEmpty) return Stream.value(null);
  return ref.watch(chatRepositoryProvider).watchThread(chatId);
});

final myThreadsProvider = StreamProvider.autoDispose<List<ChatThread>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(chatRepositoryProvider).watchThreads(user.uid);
});

/// Belirli bir sohbetin mesajları (canlı).
/// autoDispose: sohbet kapanınca listener + bellek serbest kalsın.
final messagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).watchMessages(chatId);
});

/// Denormalize sohbet okunmamış sayacı (`private/chatMeta`).
/// Alt bar + menü bunu izler; maliyet: tek döküman snapshot.
final chatUnreadMetaProvider = StreamProvider<ChatUnreadMeta>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(ChatUnreadMeta.zero);
  return ref.watch(chatRepositoryProvider).watchUnreadMeta(user.uid);
});

/// Oturum açmış kullanıcının toplam okunmamış sohbet sayısı (alt bar rozeti).
final totalUnreadProvider = Provider<int>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;
  return ref.watch(chatUnreadMetaProvider).valueOrNull?.total ?? 0;
});

/// Okunmamışları TARAFA göre ayırır (tek hesap, çift rol).
final unreadBySideProvider = Provider<({int customer, int artisan})>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return (customer: 0, artisan: 0);
  final meta = ref.watch(chatUnreadMetaProvider).valueOrNull;
  if (meta == null) return (customer: 0, artisan: 0);
  return (customer: meta.customer, artisan: meta.artisan);
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
