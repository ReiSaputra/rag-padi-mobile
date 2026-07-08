// lib/features/chat/ui/chat_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../data/chat_models.dart';
import '../providers/chat_provider.dart';

class ChatDetailPage extends ConsumerStatefulWidget {
  final String sessionId;
  final String preview;
  final String createdAt;
  final List<ChatMessage>? initialMessages;

  const ChatDetailPage({
    super.key,
    required this.sessionId,
    required this.preview,
    required this.createdAt,
    this.initialMessages,
  });

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialMessages != null) {
        ref
            .read(chatDetailProvider.notifier)
            .loadFromHistory(widget.sessionId, widget.initialMessages!);
      } else {
        // Buka dari histori — fetch history dari server
        ref.read(chatDetailProvider.notifier).loadSession(widget.sessionId);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final msg = _controller.text.trim();
    if (msg.isEmpty || _sending) return;

    _controller.clear();
    setState(() => _sending = true);

    try {
      await ref.read(chatDetailProvider.notifier).sendMessage(msg);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim: $e'),
          backgroundColor: kColorDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatDetailProvider);

    // Auto-scroll saat ada pesan baru
    messagesAsync.whenData((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: kColorScaffold,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            _ChatHeader(preview: widget.preview, createdAt: widget.createdAt),

            // ── Area chat ─────────────────────────────────────────────────
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: kColorPrimary),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Gagal memuat percakapan.\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kColorTextMuted),
                  ),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'Belum ada pesan.\nKirim pertanyaan untuk mulai.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kColorTextMuted, fontSize: 13),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: kPadPage,
                      vertical: 12,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) =>
                        _ChatBubble(message: messages[index]),
                  );
                },
              ),
            ),

            // ── Input bar ─────────────────────────────────────────────────
            _InputBar(
              controller: _controller,
              sending: _sending,
              onSend: _send,
            ),

            // ── Bottom nav ────────────────────────────────────────────────
            _BottomNav(),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _ChatHeader extends StatelessWidget {
  final String preview;
  final String createdAt;

  const _ChatHeader({required this.preview, required this.createdAt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: const BoxDecoration(
        color: kColorSurface,
        border: Border(bottom: BorderSide(color: kColorDivider)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: kColorText),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  preview.isNotEmpty ? preview : 'Percakapan',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kColorText,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (createdAt.isNotEmpty)
                  Text(
                    createdAt,
                    style: kStyleMuted,
                    textAlign: TextAlign.right,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bubble chat ───────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final bulan = const [
        '',
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ][dt.month];
      return '${dt.day} $bulan ${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Label role
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              isUser ? 'User' : 'Ai',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isUser ? kColorPrimary : kColorTextMuted,
              ),
            ),
          ),

          // Bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isUser ? kColorPrimary : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(kRadius),
                topRight: const Radius.circular(kRadius),
                bottomLeft: Radius.circular(isUser ? kRadius : 2),
                bottomRight: Radius.circular(isUser ? 2 : kRadius),
              ),
              border: isUser ? null : Border.all(color: kColorDivider),
            ),
            child: Text(
              message.content,
              style: TextStyle(
                color: isUser ? Colors.white : kColorText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),

          // Timestamp
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_formatTime(message.createdAt), style: kStyleMuted),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: kColorSurface,
        border: Border(top: BorderSide(color: kColorDivider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Ketik pertanyaan...',
                hintStyle: const TextStyle(
                  color: kColorTextMuted,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: kColorBgNeutral,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kRadius),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: sending
                    ? kColorPrimaryMid.withOpacity(0.5)
                    : kColorPrimaryMid,
                borderRadius: BorderRadius.circular(kRadius),
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom Nav ────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kColorSurface,
        border: Border(top: BorderSide(color: kColorDivider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                label: 'Beranda',
                isActive: false,
                onTap: () {
                  // Kembali ke root (home)
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              _NavItem(
                icon: Icons.chat_bubble_rounded,
                label: 'Chat',
                isActive: true,
                onTap: () => Navigator.pop(context),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profil',
                isActive: false,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? kColorPrimary : kColorTextMuted;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 4),
            Container(
              width: 20,
              height: 3,
              decoration: BoxDecoration(
                color: kColorPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
