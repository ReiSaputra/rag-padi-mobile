// lib/features/chat/ui/chat_list_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../home/providers/home_provider.dart';
import '../../home/data/home_models.dart';
import '../providers/chat_provider.dart';
import 'chat_detail_page.dart';
import 'widgets/new_chat_dialog.dart';

class ChatListPage extends ConsumerWidget {
  const ChatListPage({super.key});

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day} ${_bulan(dt.month)} ${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _bulan(int m) => const [
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
  ][m];

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLarge),
        ),
        title: const Text(
          'Hapus Percakapan',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Percakapan ini akan dihapus permanen beserta seluruh isinya dan '
          'tidak bisa dikembalikan. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: kColorTextMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kColorDanger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kRadius),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(chatRepositoryProvider).deleteChat(sessionId);
      ref.invalidate(historyProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Percakapan berhasil dihapus.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus: $e'),
            backgroundColor: kColorDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: kColorScaffold,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(kPadPage, 12, kPadPage, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jenis Stasiun',
                    style: TextStyle(fontSize: 11, color: kColorTextMuted),
                  ),
                  Text(
                    'AWS-003',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kColorText,
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(kPadPage, 16, kPadPage, 12),
              child: Text('Percakapan', style: kStyleSectionTitle),
            ),

            // ── List ─────────────────────────────────────────────────────
            Expanded(
              child: historyAsync.when(
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
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        'Belum ada percakapan.\nTekan + untuk mulai.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kColorTextMuted, fontSize: 14),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: kColorPrimary,
                    onRefresh: () async => ref.invalidate(historyProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        kPadPage,
                        0,
                        kPadPage,
                        100,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _ChatCard(
                        item: items[index],
                        formatDate: _formatDate,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailPage(
                                sessionId: items[index].sessionId,
                                preview: items[index].preview,
                                createdAt: _formatDate(items[index].createdAt),
                              ),
                            ),
                          ).then((_) => ref.invalidate(historyProvider));
                        },
                        onDelete: () => _confirmDelete(
                          context,
                          ref,
                          items[index].sessionId,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // BUG-008 (fixed): sebelumnya _BottomNav diletakkan di dalam body
      // (child terakhir Column), sehingga Scaffold tidak tahu ada nav bar
      // custom di situ dan menghitung posisi FAB tanpa memperhitungkan
      // tingginya — akibatnya FAB menabrak/menutupi item "Profil".
      // Sekarang _BottomNav dipindah ke slot resmi bottomNavigationBar,
      // supaya Scaffold otomatis menggeser FAB ke atas nav bar ini.
      bottomNavigationBar: const _BottomNav(current: 1),

      // ── FAB: Chat mandiri baru ────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (_) => const NewChatDialog(),
          );
          if (result == true) {
            ref.invalidate(historyProvider);
          }
        },
        backgroundColor: kColorPrimary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Card percakapan ───────────────────────────────────────────────────────────
class _ChatCard extends StatelessWidget {
  final HistoryItem item;
  final String Function(String) formatDate;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ChatCard({
    required this.item,
    required this.formatDate,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAnalisis = item.type == 'analisis';
    final badgeLabel = isAnalisis ? 'Analisis Sensor' : 'Tanya Jawab';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kColorPrimary,
          borderRadius: BorderRadius.circular(kRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.preview.isNotEmpty
                        ? item.preview
                        : 'Petani bertanya tentang...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatDate(item.createdAt),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  // Badge tipe
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Menu: hapus sesi (sebelumnya placeholder statis, sekarang aktif)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, color: Colors.white54),
              color: kColorSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kRadius),
              ),
              onSelected: (value) {
                if (value == 'hapus') onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'hapus',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: kColorDanger, size: 18),
                      SizedBox(width: 8),
                      Text('Hapus', style: TextStyle(color: kColorDanger)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Nav (reusable) ─────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int current;
  const _BottomNav({required this.current});

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
                activeIcon: Icons.home_rounded,
                label: 'Beranda',
                isActive: current == 0,
                onTap: () => Navigator.pop(context),
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Chat',
                isActive: current == 1,
                onTap: () {},
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profil',
                isActive: current == 2,
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
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
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
          Icon(isActive ? activeIcon : icon, color: color, size: 24),
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
