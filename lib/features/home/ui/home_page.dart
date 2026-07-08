// lib/features/home/ui/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../providers/home_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/sensor_card.dart';
import 'widgets/analysis_result.dart';
import 'widgets/history_list.dart';
import '../../chat/ui/chat_list_page.dart';
import '../../auth/ui/profile_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  String _formatTimeSensor(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day} ${_bulan(dt.month)} ${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensorAsync = ref.watch(sensorProvider);
    final historyAsync = ref.watch(historyProvider);
    final analyzeAsync = ref.watch(analyzeProvider);
    final authState = ref.watch(authProvider).value;
    final userName = authState?.name ?? 'Petani';

    return Scaffold(
      backgroundColor: kColorScaffold,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ───────────────────────────────────────────────────
            _AppBar(userName: userName),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: kColorPrimary,
                onRefresh: () async {
                  ref.invalidate(sensorProvider);
                  ref.invalidate(historyProvider);
                  ref.read(analyzeProvider.notifier).reset();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: kPadPage,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting
                      Text(
                        'Halo, $userName!',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: kColorText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Apa ada yang bisa dibantu hari ini?',
                        style: TextStyle(fontSize: 14, color: kColorTextMuted),
                      ),
                      const SizedBox(height: 20),

                      // ── Data Sensor ───────────────────────────────────
                      sensorAsync.when(
                        loading: () =>
                            const _SectionSkeleton(label: 'Data sensor'),
                        error: (e, _) => _ErrorCard(message: e.toString()),
                        data: (sensor) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Data sensor',
                                  style: kStyleSectionTitle,
                                ),
                                Text(
                                  _formatTimeSensor(sensor.time),
                                  style: kStyleMuted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SensorGrid(sensor: sensor),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Tombol Analisis ───────────────────────────────
                      _AnalysisButton(
                        isLoading: analyzeAsync is AsyncLoading,
                        onPressed: analyzeAsync is AsyncLoading
                            ? null
                            : () =>
                                  ref.read(analyzeProvider.notifier).analyze(),
                      ),

                      const SizedBox(height: 20),

                      // ── Hasil Analisis ────────────────────────────────
                      analyzeAsync.when(
                        loading: () => const _AnalysisLoadingCard(),
                        error: (e, _) =>
                            _ErrorCard(message: 'Gagal menganalisis: $e'),
                        data: (result) {
                          if (result == null) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hasil analisis',
                                style: kStyleSectionTitle,
                              ),
                              const SizedBox(height: 10),
                              AnalysisResult(result: result),
                              const SizedBox(height: 20),
                            ],
                          );
                        },
                      ),

                      // ── Histori ───────────────────────────────────────
                      const Text(
                        'Histori percakapan',
                        style: kStyleSectionTitle,
                      ),
                      const SizedBox(height: 10),

                      historyAsync.when(
                        loading: () => const _SectionSkeleton(label: ''),
                        error: (e, _) => _ErrorCard(message: e.toString()),
                        data: (items) => HistoryList(items: items),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom Nav ────────────────────────────────────────────────
            _BottomNav(current: 0, ref: ref),
          ],
        ),
      ),
    );
  }
}

// ── App Bar ───────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final String userName;
  const _AppBar({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadPage, 12, kPadPage, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Jenis Stasiun',
            style: TextStyle(fontSize: 11, color: kColorTextMuted),
          ),
          const Text(
            'AWS-003',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kColorText,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Tanya',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                        color: kColorText,
                      ),
                    ),
                    TextSpan(
                      text: 'Padi',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kColorPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kColorBgGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: kColorPrimary,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tombol Analisis ───────────────────────────────────────────────────────────
class _AnalysisButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  const _AnalysisButton({required this.isLoading, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kColorPrimaryMid,
          foregroundColor: Colors.white,
          disabledBackgroundColor: kColorPrimaryMid.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadius),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Analisis',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

// ── Loading card analisis ─────────────────────────────────────────────────────
class _AnalysisLoadingCard extends StatelessWidget {
  const _AnalysisLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kColorPrimary,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Menganalisis data sensor...',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────
class _SectionSkeleton extends StatelessWidget {
  final String label;
  const _SectionSkeleton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: kStyleSectionTitle),
          const SizedBox(height: 10),
        ],
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: kColorDivider,
            borderRadius: BorderRadius.circular(kRadius),
          ),
        ),
      ],
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kColorBgDanger,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kColorBgDangerBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: kColorDanger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: kColorDanger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int current;
  final WidgetRef ref;
  const _BottomNav({required this.current, required this.ref});

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
                onTap: () {},
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Chat',
                isActive: current == 1,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatListPage()),
                ),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profil',
                isActive: current == 2,
                // BUG-009 (fixed): sebelumnya tab ini langsung memicu dialog
                // logout tanpa ada halaman profil sama sekali. Sekarang
                // navigasi ke ProfilePage — logout dipindah jadi tombol di
                // dalam halaman itu.
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                ),
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
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    this.onTap,
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