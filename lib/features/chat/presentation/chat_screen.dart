import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../data/models/chat.dart';
import '../../auth/application/auth_controller.dart';
import '../../storage/storage_repository.dart';
import '../data/chat_providers.dart';

/// Ekran E — Gerçek zamanlı sohbet. Metin + fotoğraf. İletişim bilgisi
/// paylaşımı otomatik maskelenir ve gönderen uyarılır (PRD §5).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId});
  final String chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  int _markedCount = -1;

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
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
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

  Future<void> _sendPhoto() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: AppConstants.imagePickMaxWidth,
          imageQuality: AppConstants.imagePickImageQuality);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > AppConstants.maxPhotoSizeBytes) {
        if (mounted) context.showError('Görsel 5 MB\'dan küçük olmalı.');
        return;
      }
      setState(() => _sending = true);
      final handle = await ref
          .read(storageRepositoryProvider)
          .uploadImage(pathHint: 'chat', bytes: bytes);
      await ref.read(chatRepositoryProvider).sendMessage(
            chatId: widget.chatId,
            senderUid: user.uid,
            imageHandle: handle,
          );
      _scrollToBottom();
    } catch (e, st) {
      // TANI: gerçek hatayı terminale bas (Storage izin/CORS/ağ vb.).
      debugPrint('[TANI][sohbet-foto] $e');
      debugPrint('$st');
      if (mounted) context.showError('Fotoğraf gönderilemedi.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
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
    final VoidCallback? goOtherProfile = (user == null || thread == null)
        ? null
        : isCustomer
            ? () => context.push(RoutePaths.artisanProfile(thread.artisanUid))
            : () => _CustomerPreviewSheet.show(
                  context,
                  name: title,
                  photo: otherPhoto,
                );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: goOtherProfile,
          borderRadius: BorderRadius.circular(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PartyAvatar(name: title, photo: otherPhoto, size: 36),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(
                      isCustomer ? 'Usta · profili gör' : 'Müşteri',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (isCustomer)
            TextButton.icon(
              icon: const Icon(Icons.star_outline, size: 18),
              label: const Text('Değerlendir'),
              onPressed: () =>
                  context.push(RoutePaths.review(thread.artisanUid)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Mesajlar yüklenemedi:\n$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const _EmptyChat();
                }
                _maybeMarkRead(messages.length);
                final otherRead = (user != null && thread != null)
                    ? ref.read(chatRepositoryProvider).lastReadAt(
                        chatId: widget.chatId,
                        uid: thread.otherUid(user.uid))
                    : null;
                return ResponsiveCenter(
                  maxWidth: 760,
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      final isMine = msg.senderUid == user?.uid;
                      final showDate = i == 0 ||
                          !_sameDay(messages[i - 1].createdAt, msg.createdAt);
                      final isRead = isMine &&
                          otherRead != null &&
                          !otherRead.isBefore(msg.createdAt);
                      // Instagram tarzı gruplama: aynı göndericinin ardışık
                      // mesajları grup sayılır; avatar yalnızca grubun SON
                      // mesajında görünür, grup içi dikey boşluk daralır.
                      final isLastOfGroup = i == messages.length - 1 ||
                          messages[i + 1].senderUid != msg.senderUid ||
                          !_sameDay(msg.createdAt, messages[i + 1].createdAt);
                      return Column(
                        children: [
                          if (showDate) _DateChip(date: msg.createdAt),
                          _Bubble(
                            message: msg,
                            isMine: isMine,
                            isRead: isRead,
                            isLastOfGroup: isLastOfGroup,
                            // Karşı tarafın mesajında avatar (#10); dokununca
                            // karşı tarafın profili açılır.
                            senderName: isMine ? null : title,
                            senderPhoto: isMine ? null : otherPhoto,
                            onAvatarTap: isMine ? null : goOtherProfile,
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
          _InputBar(
            controller: _controller,
            sending: _sending,
            onSend: _sendText,
            onPhoto: _sendPhoto,
          ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

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
    return DateFormat('d MMMM yyyy', 'tr_TR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(_label(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant)),
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
  });
  final ChatMessage message;
  final bool isMine;
  final bool isRead;
  final bool isLastOfGroup;
  final String? senderName;
  final String? senderPhoto;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isMine ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = isMine ? scheme.onPrimary : scheme.onSurface;
    final time = DateFormat('HH:mm').format(message.createdAt);

    final bubble = Container(
        constraints: const BoxConstraints(maxWidth: 300),
        // Grup içinde daralan boşluk; grup sonunda nefes payı.
        margin: EdgeInsets.only(top: 1.5, bottom: isLastOfGroup ? 8 : 1.5),
        padding: message.hasImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.fromLTRB(14, 9, 14, 7),
        decoration: BoxDecoration(
          color: bg,
          // Instagram'a yakın: iyice yuvarlak; kuyruk yalnız grubun sonunda.
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMine || !isLastOfGroup ? 20 : 5),
            bottomRight: Radius.circular(!isMine || !isLastOfGroup ? 20 : 5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: AppImage(handle: message.imageHandle!),
                ),
              ),
            if (message.text != null && message.text!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: message.hasImage ? 6 : 0),
                child: Text(message.text!, style: TextStyle(color: fg)),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time,
                      style: TextStyle(
                          fontSize: 10, color: fg.withValues(alpha: 0.7))),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isRead ? Icons.done_all : Icons.done,
                      size: 13,
                      color: isRead
                          ? const Color(0xFF6FD3FF)
                          : fg.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

    if (isMine) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    // Karşı tarafın mesajı: avatar YALNIZ grubun son mesajında (Instagram);
    // diğerlerinde hizayı koruyan boşluk. Dokununca karşı profil açılır.
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

/// Sohbette karşı tarafı temsil eden küçük yuvarlak avatar; fotoğraf yoksa
/// baş harf gösterir.
class _PartyAvatar extends StatelessWidget {
  const _PartyAvatar({required this.name, this.photo, this.size = 32});
  final String name;
  final String? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: photo != null
            ? AppImage(handle: photo)
            : Container(
                color: scheme.primaryContainer,
                alignment: Alignment.center,
                child: Text(
                  name.trim().isEmpty
                      ? '?'
                      : name.trim().substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onPhoto,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ResponsiveCenter(
        maxWidth: 760,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.photo_camera_back_outlined),
                onPressed: sending ? null : onPhoto,
                tooltip: 'Fotoğraf gönder',
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Mesaj yazın…',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: sending ? null : onSend,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(14),
                ),
                child: const Icon(Icons.send_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Sohbeti başlatın. İletişim bilgileri (telefon, e-posta, sosyal medya) '
          'güvenliğiniz için otomatik gizlenir.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
