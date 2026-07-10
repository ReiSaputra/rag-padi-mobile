// lib/features/home/ui/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../core/api_error.dart';
import '../providers/home_provider.dart';
import '../data/home_models.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/sensor_card.dart';
import 'widgets/analysis_result.dart';
import 'widgets/history_list.dart';
import 'widgets/sensor_input_page.dart';
import '../../../shared/widgets/app_bottom_nav.dart';

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

    // User baru (belum pernah POST /sensor) akan selalu dapat 404 di sini —
    // itu bukan error, jadi tombol Analisis sengaja dinonaktifkan sampai
    // ada data, daripada membiarkan user menekannya dan dapat error lagi.
    final hasSensor = sensorAsync.maybeWhen(
      data: (_) => true,
      orElse: () => false,
    );

    Future<void> _openSensorForm() async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SensorInputPage()),
      );
      // sensorProvider & analyzeProvider sudah di-invalidate otomatis di
      // dalam SensorInputNotifier.submit() saat sukses — tidak perlu
      // invalidate manual lagi di sini.
    }

    return Scaffold(
      backgroundColor: kColorScaffold,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ───────────────────────────────────────────────────
            _AppBar(
              userName: userName,
              // BUG FIX: sensorAsync.value RETHROW error kalau state-nya
              // AsyncError (beda dari .valueOrNull yang aman) — sebelumnya
              // ini bikin exception dari 500/404 kelempar di tempat yang
              // salah (sebelum sempat ditangkap sensorAsync.when() di
              // bawah), bikin seluruh HomePage crash walau sudah ada
              // penanganan error yang rapi untuk kasus itu. maybeWhen di
              // sini aman: null kalau bukan AsyncData (loading/error).
              stationLabel: sensorSourceLabel(
                sensorAsync.maybeWhen(data: (s) => s, orElse: () => null),
              ),
            ),

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
                        error: (e, _) => isNotFoundError(e)
                            ? _SensorEmptyState(onTap: _openSensorForm)
                            : _ErrorCard(message: apiErrorMessage(e)),
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
                                Row(
                                  children: [
                                    Text(
                                      _formatTimeSensor(sensor.time),
                                      style: kStyleMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    // Update manual — selalu tersedia, tidak
                                    // cuma untuk empty state, supaya user
                                    // bisa refresh reading kapan pun.
                                    IconButton(
                                      onPressed: _openSensorForm,
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: kColorPrimary,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Input data sensor manual',
                                    ),
                                  ],
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
                        onPressed: (analyzeAsync is AsyncLoading || !hasSensor)
                            ? null
                            : () =>
                                  ref.read(analyzeProvider.notifier).analyze(),
                      ),
                      if (!hasSensor) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Input data sensor dulu untuk mulai analisis.',
                          style: kStyleMuted,
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ── Hasil Analisis ────────────────────────────────
                      analyzeAsync.when(
                        loading: () => const _AnalysisLoadingCard(),
                        error: (e, _) => isNotFoundError(e)
                            // Sudah ditangani oleh empty state + tombol
                            // Analisis yang dinonaktifkan di atas — tidak
                            // perlu tampilkan error kedua untuk hal yang
                            // sama.
                            ? const SizedBox.shrink()
                            : _ErrorCard(
                                message:
                                    'Gagal menganalisis: ${apiErrorMessage(e)}',
                              ),
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
                        error: (e, _) =>
                            _ErrorCard(message: apiErrorMessage(e)),
                        data: (items) => HistoryList(items: items),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom Nav ────────────────────────────────────────────────
            const AppBottomNav(current: AppTab.beranda),
          ],
        ),
      ),
    );
  }
}

// ── App Bar ───────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final String userName;
  final String stationLabel;
  const _AppBar({required this.userName, required this.stationLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadPage, 12, kPadPage, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sumber Data',
            style: TextStyle(fontSize: 11, color: kColorTextMuted),
          ),
          Text(
            stationLabel,
            style: const TextStyle(
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

// ── Empty state: belum ada data sensor ────────────────────────────────────────
// Ditampilkan saat GET /sensor/latest (atau /analyze) balas 404 — ini
// SENGAJA dibedakan dari _ErrorCard, karena bukan kegagalan sistem, cuma
// user (biasanya baru daftar) belum pernah input data sensor untuk lahannya.
class _SensorEmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _SensorEmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kColorBgGreen,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Column(
        children: [
          const Icon(Icons.sensors_outlined, color: kColorPrimary, size: 32),
          const SizedBox(height: 10),
          const Text(
            'Belum Ada Data Sensor',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kColorText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Input data sensor lahan kamu untuk mulai memakai TanyaPadi.',
            style: TextStyle(
              fontSize: 12.5,
              color: kColorTextMuted,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Input Data Sensor',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorPrimaryMid,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadius),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
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
