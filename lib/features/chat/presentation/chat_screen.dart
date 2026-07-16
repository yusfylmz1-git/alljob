import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/blocked_user.dart';
import '../../../data/models/chat.dart';
import '../../../data/models/job.dart';
import '../../../data/models/report.dart';
import '../../auth/application/auth_controller.dart';
import '../../jobs/data/job_providers.dart';
import '../../jobs/presentation/job_completion.dart';
import '../../safety/data/safety_providers.dart';
import '../../safety/presentation/report_sheet.dart';
import '../../storage/storage_repository.dart';
import '../data/chat_providers.dart';

/// Ekran E — Gerçek zamanlı sohbet. Metin + fotoğraf. İletişim bilgisi
/// paylaşımı otomatik maskelenir ve gönderen uyarılır (PRD §5).
///
/// Liste `reverse: true` çalışır: sohbet AÇILIR AÇILMAZ en son mesaj görünür
/// ve yeni mesaj gelince liste dipte kalır (WhatsApp/Instagram davranışı).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId});
  final String chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

/// Yüklenmesi süren (henüz gönderilmemiş) fotoğraf: balon hemen çizilir,
/// üstünde yükleme göstergesi döner (WhatsApp modeli). Hata olursa balona
/// dokunarak tekrar denenir.
class _PendingUpload {
  _PendingUpload(this.bytes);
  final Uint8List bytes;
  bool failed = false;
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_PendingUpload> _pending = [];
  bool _photoPrecached = false;
  int _markedCount = -1;

  /// İlk yüklemede animasyon yok; sonraki yeni mesajlar girer.
  bool _historySeeded = false;
  final Set<String> _seenMessageIds = {};

  /// Çoklu silme modu: üst bardaki çöp kutusuyla açılır; kutucuklarla seçilen
  /// KENDİ mesajları topluca silinir (başkasının mesajı seçilemez).
  bool _selectionMode = false;
  final Set<String> _selected = {};

  /// Spam koruması: son gönderim anı + 60 sn içi zaman damgaları.
  DateTime? _lastSendAt;
  final List<DateTime> _sendTimestamps = [];

  /// true = spam / hız limiti; kullanıcıya toast gösterildi.
  bool _throttleSend() {
    final now = DateTime.now();
    _sendTimestamps.removeWhere(
      (t) => now.difference(t) > const Duration(seconds: 60),
    );
    if (_sendTimestamps.length >= AppConstants.maxMessagesPerMinute) {
      context.showError(
        'Çok hızlı mesaj gönderiyorsunuz. Bir dakika sonra tekrar deneyin.',
      );
      return true;
    }
    if (_lastSendAt != null &&
        now.difference(_lastSendAt!) < AppConstants.minMessageInterval) {
      context.showInfo('Biraz yavaş…');
      return true;
    }
    _lastSendAt = now;
    _sendTimestamps.add(now);
    return false;
  }

  void _exitSelection() => setState(() {
        _selectionMode = false;
        _selected.clear();
      });

  void _toggleSelected(String id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  Future<void> _deleteSelected(String uid) async {
    final count = _selected.length;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$count mesajı sil'),
        content: const Text('Seçilen mesajlar herkes için silinir; yerlerinde '
            '"Bu mesaj silindi" görünür.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final repo = ref.read(chatRepositoryProvider);
    var failed = 0;
    for (final id in _selected.toList()) {
      try {
        await repo.deleteMessage(
            chatId: widget.chatId, messageId: id, senderUid: uid);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    _exitSelection();
    if (failed > 0) {
      context.showError('$failed mesaj silinemedi, tekrar deneyin.');
    } else {
      context.showInfo(count == 1 ? 'Mesaj silindi.' : '$count mesaj silindi.');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Görüntülenen mesajları okundu işaretler (mesaj sayısı değiştikçe bir kez).
  void _maybeMarkRead(int messageCount) {
    if (messageCount == _markedCount) return;
    _markedCount = messageCount;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatRepositoryProvider)
          .markRead(chatId: widget.chatId, uid: user.uid);
    });
  }

  Future<void> _sendText() async {
    final text = Validators.sanitizeFreeText(_controller.text);
    final textErr = Validators.freeText(
      text,
      max: AppConstants.maxMessageLength,
      field: 'Mesaj',
    );
    if (text.isEmpty) return;
    if (textErr != null) {
      context.showError(textErr);
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    if (_iBlockedOther(user.uid)) return;
    if (_throttleSend()) return;
    HapticFeedback.lightImpact();
    _controller.clear();
    try {
      final masked = await ref.read(chatRepositoryProvider).sendMessage(
            chatId: widget.chatId,
            senderUid: user.uid,
            text: text,
          );
      if (masked && mounted) {
        context.showInfo(
            'Güvenliğiniz için iletişim bilgileri gizlendi. Görüşmeleri uygulama içinde sürdürün.');
      }
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        _controller.text = text; // mesajı kaybetme, tekrar denenebilsin
        context.showError('Mesaj gönderilemedi. Bağlantını kontrol edip '
            'tekrar dene.');
      }
    }
  }

  /// Kullanıcı karşı tarafı ENGELLEDİYSE gönderim yapılmaz (kural zaten
  /// alıcı-engelledi yönünü sunucuda keser; bu, engelleyenin kendi yönü).
  bool _iBlockedOther(String myUid) {
    final thread = ref.read(chatRepositoryProvider).getThread(widget.chatId);
    final blocked = thread != null &&
        ref.read(myBlockedUidsProvider).contains(thread.otherUid(myUid));
    if (blocked) {
      context.showError('Engellediğiniz kullanıcıya mesaj gönderemezsiniz. '
          'Önce engeli kaldırın.');
    }
    return blocked;
  }

  Future<void> _sendPhoto() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    if (_iBlockedOther(user.uid)) return;
    if (_throttleSend()) return;
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: AppConstants.imagePickMaxWidth,
          imageQuality: AppConstants.imagePickImageQuality);
    } catch (e) {
      debugPrint('[TANI][sohbet-foto-secim] $e');
      if (mounted) context.showError('Fotoğraf seçilemedi.');
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > AppConstants.maxPhotoSizeBytes) {
      if (mounted) context.showError('Görsel 5 MB\'dan küçük olmalı.');
      return;
    }
    // Balon HEMEN görünür; yükleme arka planda sürer (giriş kilitlenmez,
    // kullanıcı bu sırada yazabilir veya başka fotoğraf seçebilir).
    final item = _PendingUpload(bytes);
    setState(() => _pending.add(item));
    _scrollToBottom();
    await _startUpload(item, user.uid);
  }

  Future<void> _startUpload(_PendingUpload item, String uid) async {
    try {
      final handle = await ref
          .read(storageRepositoryProvider)
          .uploadImage(pathHint: 'chat/$uid', bytes: item.bytes);
      await ref.read(chatRepositoryProvider).sendMessage(
            chatId: widget.chatId,
            senderUid: uid,
            imageHandle: handle,
          );
      if (mounted) setState(() => _pending.remove(item));
      _scrollToBottom();
    } catch (e, st) {
      // TANI: gerçek hatayı terminale bas (Storage izin/CORS/ağ vb.).
      debugPrint('[TANI][sohbet-foto] $e');
      debugPrint('$st');
      if (mounted) {
        setState(() => item.failed = true);
        context.showError(
            'Fotoğraf gönderilemedi. Balona dokunup tekrar deneyin.');
      }
    }
  }

  /// Başarısız yüklemeye dokununca: tekrar dene / kaldır.
  Future<void> _pendingTapped(_PendingUpload item) async {
    if (!item.failed) return; // yükleme sürüyor
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Tekrar dene'),
              onTap: () => Navigator.pop(ctx, 'retry'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Kaldır'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'retry') {
      setState(() => item.failed = false);
      await _startUpload(item, user.uid);
    } else if (action == 'remove') {
      setState(() => _pending.remove(item));
    }
  }

  /// Mesaja uzun basınca: kopyala (metin) / sil (kendi) / şikayet (karşı taraf).
  Future<void> _showMessageActions(ChatMessage msg, bool isMine) async {
    final canCopy = !msg.deleted && (msg.text?.isNotEmpty ?? false);
    final canDelete = isMine && !msg.deleted;
    final canReport = !isMine && !msg.deleted; // UGC politikası
    if (!canCopy && !canDelete && !canReport) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canCopy)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Kopyala'),
                onTap: () => Navigator.pop(ctx, 'copy'),
              ),
            if (canReport)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Şikayet et'),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Mesajı sil',
                    style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: msg.text!));
      if (mounted) context.showInfo('Kopyalandı.');
      return;
    }

    if (action == 'report') {
      await showReportSheet(
        context,
        ref,
        target: ReportTarget.message,
        targetId: '${widget.chatId}_${msg.id}',
        reportedUid: msg.senderUid,
        chatId: widget.chatId,
      );
      return;
    }

    // Silme: onay iste (geri alınamaz; karşı taraf "Bu mesaj silindi" görür).
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mesajı sil'),
        content: const Text('Mesaj herkes için silinir; yerinde '
            '"Bu mesaj silindi" görünür.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(chatRepositoryProvider).deleteMessage(
            chatId: widget.chatId,
            messageId: msg.id,
            senderUid: msg.senderUid,
          );
    } catch (_) {
      if (mounted) context.showError('Mesaj silinemedi, tekrar deneyin.');
    }
  }

  /// Karşı tarafı engeller / engeli kaldırır (üst bar menüsü).
  /// Engelleme onay ister; başarıda sohbet listeden gizleneceği için
  /// ekrandan çıkılır. Engellenen kişi engellendiğini görmez (IG modeli).
  Future<void> _toggleBlock(
      String myUid, ChatThread thread, bool currentlyBlocked) async {
    final otherUid = thread.otherUid(myUid);
    final repo = ref.read(blockRepositoryProvider);

    if (currentlyBlocked) {
      await repo.unblock(uid: myUid, otherUid: otherUid);
      if (mounted) context.showInfo('Engel kaldırıldı.');
      return;
    }

    final name = thread.otherName(myUid);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$name engellensin mi?'),
        content: const Text(
            'Engellenen kullanıcı size mesaj gönderemez ve bu sohbet '
            'listenizde gizlenir. Engeli dilediğiniz an Profil → '
            'Engellenen Kullanıcılar bölümünden kaldırabilirsiniz.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: ctx.palette.danger,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Engelle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await repo.block(
      uid: myUid,
      other: BlockedUser(
        uid: otherUid,
        name: name,
        photoUrl: thread.otherPhoto(myUid),
        blockedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    context.showInfo('Kullanıcı engellendi.');
    if (context.canPop()) context.pop(); // sohbet artık listede gizli
  }

  void _openImage(String handle) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => _ImageViewerPage(handle: handle)),
    );
  }

  void _scrollToBottom() {
    // reverse listede "en alt" = offset 0.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final thread = ref.read(chatRepositoryProvider).getThread(widget.chatId);
    final messagesAsync = ref.watch(messagesProvider(widget.chatId));
    final title = (user != null && thread != null)
        ? thread.otherName(user.uid)
        : 'Sohbet';
    // Sohbette "karşı taraf usta mı?" thread'den okunur: kullanıcı bu sohbetin
    // müşteri tarafındaysa avatar usta profiline götürür (mod fark etmez).
    final isCustomer =
        user != null && thread != null && thread.artisanUid != user.uid;

    // Karşı tarafın avatarı; dokununca profili açılır: usta → herkese açık
    // usta profili, müşteri → mini profil kartı (bottom sheet).
    final otherPhoto =
        (user != null && thread != null) ? thread.otherPhoto(user.uid) : null;
    // Thread açılır açılmaz avatarı ısıt (liste cache'i yoksa ağ beklemesin).
    if (!_photoPrecached && otherPhoto != null) {
      _photoPrecached = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AppImage.precacheHttp(context, otherPhoto);
      });
    }
    final VoidCallback? goOtherProfile = (user == null || thread == null)
        ? null
        : isCustomer
            ? () => context.push(RoutePaths.artisanProfile(thread.artisanUid))
            : () => _CustomerPreviewSheet.show(
                  context,
                  name: title,
                  photo: otherPhoto,
                );

    // Karşı taraf engellendiyse menü "Engeli Kaldır" gösterir; gönderme
    // guard'ı da (aşağıda _send/_sendPhoto) bu sete bakar.
    final otherBlocked = user != null &&
        thread != null &&
        ref.watch(myBlockedUidsProvider).contains(thread.otherUid(user.uid));

    // Kullanıcı bu sohbeti listesinden sildiyse, silme anından önceki
    // mesajlar ona artık gösterilmez (tek taraflı sohbet silme).
    final cleared = user == null
        ? null
        : ref
            .read(chatRepositoryProvider)
            .clearedAt(chatId: widget.chatId, uid: user.uid);
    List<ChatMessage> visibleOf(List<ChatMessage> all) => cleared == null
        ? all
        : [
            for (final m in all)
              if (m.createdAt.isAfter(cleared)) m
          ];

    // Çoklu silmede seçilebilecek mesajlar: kendi, henüz silinmemiş olanlar.
    final myDeletableIds = user == null
        ? const <String>[]
        : [
            for (final m in visibleOf(
                messagesAsync.valueOrNull ?? const <ChatMessage>[]))
              if (m.senderUid == user.uid && !m.deleted) m.id
          ];

    final appBar = _selectionMode
        ? AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Vazgeç',
              onPressed: _exitSelection,
            ),
            title: Text('${_selected.length} seçildi'),
            actions: [
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: 'Tümünü seç',
                onPressed: myDeletableIds.isEmpty
                    ? null
                    : () => setState(() {
                          // Hepsi seçiliyse seçim kalkar (ikinci basış).
                          if (_selected.length == myDeletableIds.length) {
                            _selected.clear();
                          } else {
                            _selected
                              ..clear()
                              ..addAll(myDeletableIds);
                          }
                        }),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Seçilenleri sil',
                onPressed: _selected.isEmpty || user == null
                    ? null
                    : () => _deleteSelected(user.uid),
              ),
            ],
          )
        : AppBar(
            titleSpacing: 0,
            surfaceTintColor: Colors.transparent,
            title: InkWell(
              onTap: goOtherProfile,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PartyAvatar(name: title, photo: otherPhoto, size: 38),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            isCustomer
                                ? 'Usta · profile git'
                                : 'Müşteri · profile bak',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: context.palette.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Mesaj sil',
                onPressed: myDeletableIds.isEmpty
                    ? null
                    : () => setState(() => _selectionMode = true),
              ),
              if (isCustomer)
                IconButton(
                  icon: const Icon(Icons.star_outline_rounded),
                  tooltip: 'Değerlendir',
                  onPressed: () =>
                      context.push(RoutePaths.review(thread.artisanUid)),
                ),
              if (user != null && thread != null)
                PopupMenuButton<String>(
                  tooltip: 'Daha fazla',
                  onSelected: (v) {
                    switch (v) {
                      case 'block':
                        _toggleBlock(user.uid, thread, otherBlocked);
                      case 'report':
                        showReportSheet(
                          context,
                          ref,
                          target: ReportTarget.user,
                          targetId: thread.otherUid(user.uid),
                          reportedUid: thread.otherUid(user.uid),
                          chatId: widget.chatId,
                        );
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'block',
                      child: Text(otherBlocked
                          ? 'Engeli Kaldır'
                          : 'Kullanıcıyı Engelle'),
                    ),
                    const PopupMenuItem(
                        value: 'report', child: Text('Şikayet Et')),
                  ],
                ),
            ],
          );

    return PopScope(
      // Geri tuşu seçim modunda ekrandan çıkmasın, seçimi kapatsın.
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelection();
      },
      child: Scaffold(
      appBar: appBar,
      backgroundColor: context.palette.background,
      // Klavye inset'ini Scaffold'a bırakMIYORUZ: varsayılan davranış klavye
      // animasyonunun HER karesinde tüm gövdeyi yeniden ölçer (mesaj listesi
      // dahil) ve açılışı hantallaştırır. Bunun yerine en alttaki tek yaprak
      // widget (_KeyboardSpacer) inset'i dinler ve yumuşak eğriyle yükselir —
      // inset'i tek seferde zıplatan cihazlarda bile WhatsApp gibi süzülür.
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // Bağlı iş varsa tamamlama durumu + hızlı onay (P0).
          if (user != null)
            _JobCompletionChatBar(chatId: widget.chatId, myUid: user.uid),
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const LoadingView(label: 'Sohbet yükleniyor…'),
              error: (err, _) {
                final denied = err.toString().contains('permission-denied');
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ErrorView(
                        message: denied
                            ? 'Sohbete erişilemedi. E-posta doğrulamanızı '
                                'kontrol edin veya biraz sonra tekrar deneyin.'
                            : 'Mesajlar yüklenemedi. Bağlantınızı kontrol edip '
                                'tekrar deneyin.',
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => ref
                            .invalidate(messagesProvider(widget.chatId)),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                );
              },
              data: (allMessages) {
                final messages = visibleOf(allMessages);
                if (messages.isEmpty && _pending.isEmpty) {
                  return const _EmptyChat();
                }
                // İlk yük: geçmişi animasyonsuz işaretle.
                if (!_historySeeded) {
                  _historySeeded = true;
                  for (final m in messages) {
                    _seenMessageIds.add(m.id);
                  }
                }
                _maybeMarkRead(messages.length);
                final otherRead = (user != null && thread != null)
                    ? ref.read(chatRepositoryProvider).lastReadAt(
                        chatId: widget.chatId,
                        uid: thread.otherUid(user.uid))
                    : null;
                return ColoredBox(
                  color: context.palette.background,
                  child: ResponsiveCenter(
                  maxWidth: 760,
                  child: ListView.builder(
                    controller: _scroll,
                    // Sohbet dipten başlar; yeni mesajda dipte kalır.
                    reverse: true,
                    // Eski mesajlara kaydırınca klavye kapanır (WhatsApp).
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: messages.length + _pending.length,
                    itemBuilder: (context, i) {
                      // reverse: i=0 EN ALTTA. Önce bekleyen yüklemeler
                      // (en yenisi dipte), sonra gerçek mesajlar.
                      if (i < _pending.length) {
                        final p = _pending[_pending.length - 1 - i];
                        return _MessageEnter(
                          isMine: true,
                          child: _PendingImageBubble(
                            item: p,
                            onTap: () => _pendingTapped(p),
                          ),
                        );
                      }
                      // Kronolojik dizin: liste ters çizildiği için çevrilir.
                      final j = messages.length - 1 - (i - _pending.length);
                      final msg = messages[j];
                      final isMine = msg.senderUid == user?.uid;
                      final showDate = j == 0 ||
                          !_sameDay(messages[j - 1].createdAt, msg.createdAt);
                      final isRead = isMine &&
                          otherRead != null &&
                          !otherRead.isBefore(msg.createdAt);
                      // Instagram tarzı gruplama: aynı göndericinin ardışık
                      // mesajları grup sayılır; avatar yalnızca grubun SON
                      // mesajında görünür, grup içi dikey boşluk daralır.
                      final isLastOfGroup = j == messages.length - 1 ||
                          messages[j + 1].senderUid != msg.senderUid ||
                          !_sameDay(msg.createdAt, messages[j + 1].createdAt);
                      // Seçim modunda seçilebilirlik: kendi, silinmemiş mesaj.
                      final selectable = isMine && !msg.deleted;
                      final isNew = !_seenMessageIds.contains(msg.id);
                      if (isNew) {
                        // Sonraki frame'de "görüldü" — yeniden animasyon yok.
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _seenMessageIds.add(msg.id);
                        });
                      }
                      final bubble = _Bubble(
                        message: msg,
                        isMine: isMine,
                        isRead: isRead,
                        isLastOfGroup: isLastOfGroup,
                        // Karşı tarafın mesajında avatar (#10); dokununca
                        // karşı tarafın profili açılır.
                        senderName: isMine ? null : title,
                        senderPhoto: isMine ? null : otherPhoto,
                        onAvatarTap:
                            isMine || _selectionMode ? null : goOtherProfile,
                        // Seçim modunda dokunuşlar seçimi yönetir; menü ve
                        // tam ekran foto devre dışı kalır.
                        onLongPress: _selectionMode
                            ? (selectable
                                ? () => _toggleSelected(msg.id)
                                : null)
                            : () => _showMessageActions(msg, isMine),
                        onImageTap: _selectionMode
                            ? (selectable
                                ? () => _toggleSelected(msg.id)
                                : null)
                            : (msg.hasImage
                                ? () => _openImage(msg.imageHandle!)
                                : null),
                      );
                      final content = !_selectionMode
                          ? bubble
                          : InkWell(
                              onTap: selectable
                                  ? () => _toggleSelected(msg.id)
                                  : null,
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _selected.contains(msg.id),
                                    onChanged: selectable
                                        ? (_) => _toggleSelected(msg.id)
                                        : null,
                                  ),
                                  Expanded(child: bubble),
                                ],
                              ),
                            );
                      return Column(
                        children: [
                          if (showDate) _DateChip(date: msg.createdAt),
                          if (isNew)
                            _MessageEnter(isMine: isMine, child: content)
                          else
                            content,
                        ],
                      );
                    },
                  ),
                ),
                );
              },
            ),
          ),
          // Seçim modunda giriş çubuğu gizlenir (WhatsApp davranışı).
          if (!_selectionMode) ...[
            if (_pending.isNotEmpty)
              Material(
                color: context.palette.card,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      const _TypingDots(),
                      const SizedBox(width: 10),
                      Text(
                        _pending.any((p) => p.failed)
                            ? 'Yükleme hatası — balona dokun'
                            : 'Fotoğraf gönderiliyor…',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: context.palette.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            _InputBar(
              controller: _controller,
              onSend: _sendText,
              onPhoto: _sendPhoto,
            ),
          ],
          // Klavye yüksekliği kadar animasyonlu boşluk (resizeToAvoidBottomInset
          // false olduğundan giriş çubuğunu klavyenin üstünde bu tutar).
          const _KeyboardSpacer(),
        ],
      ),
      ),
    );
  }
}

/// Klavye yüksekliği kadar boşluk bırakan, inset değişimini yumuşatan yaprak
/// widget. MediaQuery.viewInsetsOf'a YALNIZ bu widget abone olur → klavye
/// açılırken ekranın geri kalanında widget rebuild'i tetiklenmez; yükseklik
/// kısa bir eğriyle hedefe süzülür (inset'i tek karede zıplatan cihazlarda
/// sert sıçrama yerine akıcı kayma).
class _KeyboardSpacer extends StatelessWidget {
  const _KeyboardSpacer();

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      height: MediaQuery.viewInsetsOf(context).bottom,
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Yeni mesaj balonu: hafif kayma + fade (geçmiş mesajlar animasyonsuz).
class _MessageEnter extends StatefulWidget {
  const _MessageEnter({required this.child, required this.isMine});
  final Widget child;
  final bool isMine;

  @override
  State<_MessageEnter> createState() => _MessageEnterState();
}

class _MessageEnterState extends State<_MessageEnter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();

  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: Offset(widget.isMine ? 0.08 : -0.08, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
  late final Animation<double> _scale = Tween<double>(begin: 0.94, end: 1)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

/// Yazıyor… göstergesi (3 nokta nabız).
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_c.value + i * 0.2) % 1.0;
            final y = (t < 0.5 ? t : 1 - t) * 2; // 0→1→0
            return Container(
              margin: EdgeInsets.only(right: i == 2 ? 0 : 4, bottom: y * 4),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: palette.inkMuted.withValues(alpha: 0.45 + y * 0.45),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// Balon/ayraç başına her build'de yeniden yaratılmasın diye modül düzeyinde
// tek sefer kurulan biçimlendiriciler (liste kaydırılırken ufak ama bedava
// kazanç).
final DateFormat _timeFmt = DateFormat('HH:mm');
final DateFormat _dayFmt = DateFormat('d MMMM yyyy', 'tr_TR');

/// Mesaj akışında gün ayracı (Bugün / Dün / tarih).
class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});
  final DateTime date;

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Dün';
    return _dayFmt.format(date);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            _label(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: palette.inkMuted,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.isMine,
    this.isRead = false,
    this.isLastOfGroup = true,
    this.senderName,
    this.senderPhoto,
    this.onAvatarTap,
    this.onLongPress,
    this.onImageTap,
  });
  final ChatMessage message;
  final bool isMine;
  final bool isRead;
  final bool isLastOfGroup;
  final String? senderName;
  final String? senderPhoto;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onImageTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Benim: marka turuncusu; karşı: kart + ince gölge (WhatsApp/iMessage dili).
    final bg = isMine ? palette.primary : palette.card;
    final fg = isMine ? Colors.white : palette.ink;
    final time = _timeFmt.format(message.createdAt);

    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: EdgeInsets.only(top: 1.5, bottom: isLastOfGroup ? 10 : 2),
        padding: message.hasImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.fromLTRB(14, 10, 12, 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine || !isLastOfGroup ? 18 : 4),
            bottomRight: Radius.circular(!isMine || !isLastOfGroup ? 18 : 4),
          ),
          border: isMine
              ? null
              : Border.all(color: palette.border.withValues(alpha: 0.9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isMine ? 0.08 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.deleted)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block,
                      size: 14, color: fg.withValues(alpha: 0.55)),
                  const SizedBox(width: 5),
                  Text(
                    'Bu mesaj silindi',
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.55),
                      fontStyle: FontStyle.italic,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            if (message.hasImage)
              GestureDetector(
                onTap: onImageTap,
                child: Hero(
                  tag: 'chat-img-${message.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 220,
                      height: 220,
                      child: AppImage(
                        handle: message.imageHandle!,
                        memCacheWidth: 440,
                        memCacheHeight: 440,
                      ),
                    ),
                  ),
                ),
              ),
            if (!message.deleted &&
                message.text != null &&
                message.text!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: message.hasImage ? 6 : 0),
                child: Text(
                  message.text!,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: fg.withValues(alpha: isMine ? 0.78 : 0.55),
                    ),
                  ),
                  if (isMine && !message.deleted) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isRead ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 14,
                      color: isRead
                          ? const Color(0xFFB8E7FF)
                          : fg.withValues(alpha: 0.75),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isMine) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isLastOfGroup)
            Padding(
              padding: const EdgeInsets.only(bottom: 10, right: 6),
              child: InkWell(
                onTap: onAvatarTap,
                customBorder: const CircleBorder(),
                child: _PartyAvatar(
                  name: senderName ?? '?',
                  photo: senderPhoto,
                  size: 30,
                ),
              ),
            )
          else
            const SizedBox(width: 36),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

/// Yüklenmekte olan fotoğraf balonu: görsel hemen görünür, üstünde karartma +
/// dönen gösterge (WhatsApp). Hata olursa uyarı ikonu; dokununca tekrar
/// dene / kaldır seçenekleri.
class _PendingImageBubble extends StatelessWidget {
  const _PendingImageBubble({required this.item, required this.onTap});
  final _PendingUpload item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 1.5, bottom: 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(5),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(item.bytes, fit: BoxFit.cover),
                  Container(color: Colors.black38),
                  Center(
                    child: item.failed
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.error_outline,
                                  color: Colors.white, size: 34),
                              SizedBox(height: 6),
                              Text('Gönderilemedi\nDokun: tekrar dene',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          )
                        : const SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fotoğrafa dokununca açılan tam ekran görüntüleyici (yakınlaştırılabilir).
class _ImageViewerPage extends StatelessWidget {
  const _ImageViewerPage({required this.handle});
  final String handle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: AppImage(handle: handle, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

/// Karşı taraf MÜŞTERİ olduğunda avatara basınca açılan mini profil kartı
/// (müşterinin herkese açık profil sayfası yok — kimlik önizlemesi yeterli).
class _CustomerPreviewSheet extends StatelessWidget {
  const _CustomerPreviewSheet({required this.name, this.photo});
  final String name;
  final String? photo;

  static Future<void> show(
    BuildContext context, {
    required String name,
    String? photo,
  }) {
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => _CustomerPreviewSheet(name: name, photo: photo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PartyAvatar(name: name, photo: photo, size: 88),
            const SizedBox(height: 14),
            Text(name,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Müşteri',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Text(
              'Güvenliğiniz için görüşmeleri uygulama içinde sürdürün.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sohbette karşı tarafı temsil eden küçük yuvarlak avatar ([AppAvatar]).
class _PartyAvatar extends StatelessWidget {
  const _PartyAvatar({required this.name, this.photo, this.size = 32});
  final String name;
  final String? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AppAvatar(name: name, photo: photo, size: size);
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onPhoto,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPhoto;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _sendBump = false;

  void _handleSend() {
    setState(() => _sendBump = true);
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _sendBump = false);
    });
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      color: palette.card,
      child: SafeArea(
        top: false,
        child: ResponsiveCenter(
          maxWidth: 760,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Material(
                  color: palette.surfaceMuted,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: Icon(Icons.image_outlined, color: palette.inkMuted),
                    onPressed: widget.onPhoto,
                    tooltip: 'Fotoğraf gönder',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSend(),
                    style: const TextStyle(fontSize: 15.5, height: 1.3),
                    decoration: InputDecoration(
                      hintText: 'Mesaj yaz…',
                      filled: true,
                      fillColor: palette.surfaceMuted,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide(
                            color: palette.primary.withValues(alpha: 0.45),
                            width: 1.2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedScale(
                  scale: _sendBump ? 0.88 : 1,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutBack,
                  child: Material(
                    color: palette.primary,
                    shape: const CircleBorder(),
                    elevation: 1,
                    child: IconButton(
                      onPressed: _handleSend,
                      tooltip: 'Gönder',
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatefulWidget {
  const _EmptyChat();

  @override
  State<_EmptyChat> createState() => _EmptyChatState();
}

class _EmptyChatState extends State<_EmptyChat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                final s = 1 + (_c.value * 0.045);
                return Transform.scale(scale: s, child: child);
              },
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: palette.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.border),
                  boxShadow: [
                    BoxShadow(
                      color: palette.primary.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.lock_outline_rounded,
                    size: 34, color: palette.primary),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Güvenli sohbet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Telefon, e-posta ve sosyal medya paylaşımları otomatik '
              'gizlenir. İşinizi uygulama içinde yürütün.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.inkMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            const _TypingDots(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ba�l� i�: sohbet �st� tamamlama �eridi
// ---------------------------------------------------------------------------

class _JobCompletionChatBar extends ConsumerWidget {
  const _JobCompletionChatBar({required this.chatId, required this.myUid});

  final String chatId;
  final String myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobByChatIdProvider(chatId));
    final job = jobAsync.valueOrNull;
    if (job == null) return const SizedBox.shrink();

    // Yaln�z ba�l� / aktif veya yeni tamamlanm�� i�lerde g�ster.
    final show = job.status == JobStatus.workerSelected ||
        job.status == JobStatus.inProgress ||
        job.status == JobStatus.completed ||
        job.status == JobStatus.disputed;
    if (!show) return const SizedBox.shrink();

    final isOwner = job.customerId == myUid;
    final copy = JobCompletionCopy.of(job, isOwner: isOwner);
    final palette = context.palette;

    return Material(
      color: palette.card,
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JobCompletionStatusBanner(
              job: job,
              isOwner: isOwner,
              compact: true,
              onOpenJob: () =>
                  context.push(RoutePaths.jobDetail(job.jobId)),
            ),
            if (copy.canConfirm) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: palette.successSurface,
                  foregroundColor: palette.success,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () async {
                  try {
                    await ref.read(jobRepositoryProvider).confirmDone(
                          jobId: job.jobId,
                          byCustomer: isOwner,
                        );
                    if (context.mounted) {
                      context.showSuccess(
                        isOwner
                            ? 'Onay�n�z kaydedildi. Usta da onaylay�nca i� kapan�r.'
                            : 'Teslim onay� kaydedildi. M��teri de onaylay�nca i� kapan�r.',
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      context.showError(
                          'Onay kaydedilemedi. Ba�lant�y� kontrol edip tekrar deneyin.');
                    }
                  }
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(copy.confirmLabel),
              ),
            ],
            if (job.status == JobStatus.completed && isOwner) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  final artisanId = job.selectedArtisanId;
                  if (artisanId == null) return;
                  context.push(
                    RoutePaths.review(artisanId, jobId: job.jobId),
                  );
                },
                icon: const Icon(Icons.star_outline_rounded, size: 18),
                label: const Text('Ustay� de�erlendir'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
