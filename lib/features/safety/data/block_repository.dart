import 'dart:async';

import '../../../data/models/blocked_user.dart';

/// Kullanıcı engelleme soyutlaması (UGC politikası — P0).
///
/// Veri modeli: `users/{uid}/blocked/{otherUid}` — yalnızca sahibi okur/yazar
/// (kural). Engellenen kişi ENGELLENDİĞİNİ GÖREMEZ (IG/WhatsApp modeli);
/// engellenenin bu sohbete mesaj yazması Firestore kuralıyla reddedilir.
abstract interface class BlockRepository {
  /// [uid]'in engellediği kullanıcılar — canlı akış (yönetim ekranı + filtre).
  Stream<List<BlockedUser>> watchBlocked(String uid);

  /// [other] kullanıcısını engeller (ad/foto snapshot'ıyla).
  Future<void> block({required String uid, required BlockedUser other});

  /// Engeli kaldırır (kayıt yoksa sessizce geçer).
  Future<void> unblock({required String uid, required String otherUid});
}

/// Bellek içi mock — testler ve Firebase'siz geliştirme için.
class MockBlockRepository implements BlockRepository {
  final Map<String, Map<String, BlockedUser>> _blocked = {};
  final StreamController<void> _tick = StreamController<void>.broadcast();

  List<BlockedUser> _listFor(String uid) {
    final list = _blocked[uid]?.values.toList() ?? <BlockedUser>[];
    list.sort((a, b) => b.blockedAt.compareTo(a.blockedAt));
    return list;
  }

  @override
  Stream<List<BlockedUser>> watchBlocked(String uid) async* {
    yield _listFor(uid);
    yield* _tick.stream.map((_) => _listFor(uid));
  }

  @override
  Future<void> block({required String uid, required BlockedUser other}) async {
    (_blocked[uid] ??= {})[other.uid] = other;
    _tick.add(null);
  }

  @override
  Future<void> unblock({required String uid, required String otherUid}) async {
    _blocked[uid]?.remove(otherUid);
    _tick.add(null);
  }

  void dispose() => _tick.close();
}
