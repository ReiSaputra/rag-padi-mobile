// lib/features/home/providers/home_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/home_models.dart';
import '../data/home_repository.dart';

// Repository provider
final homeRepositoryProvider = Provider<HomeRepository>(
  (_) => HomeRepository(),
);

// Sensor provider
final sensorProvider = FutureProvider<SensorData>((ref) {
  return ref.watch(homeRepositoryProvider).fetchLatestSensor();
});

// History provider
final historyProvider = FutureProvider<List<HistoryItem>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchHistory();
});

// Analyze state
// Menyimpan hasil analisis terakhir (null = belum dianalisis)
class AnalyzeNotifier extends StateNotifier<AsyncValue<AnalyzeResult?>> {
  final HomeRepository _repo;
  final Ref _ref;

  AnalyzeNotifier(this._ref, this._repo) : super(const AsyncValue.data(null));

  Future<void> analyze() async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.analyze();
      state = AsyncValue.data(result);
      // BUG-003 (fixed): tanpa invalidate ini, historyProvider (FutureProvider)
      // tetap pakai cache lama — histori percakapan di beranda tidak
      // menampilkan sesi analisis baru sampai user refresh manual.
      _ref.invalidate(historyProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

final analyzeProvider =
    StateNotifierProvider<AnalyzeNotifier, AsyncValue<AnalyzeResult?>>((ref) {
      return AnalyzeNotifier(ref, ref.watch(homeRepositoryProvider));
    });

// ══════════════════════════════════════════════════════════════════════════════
// Sensor Input Notifier (POST /sensor — form manual)
// State cuma menandai proses submit sedang berjalan/gagal — data hasil
// tidak disimpan di sini karena sensorProvider yang jadi sumber kebenaran
// untuk "data sensor terbaru" (di-invalidate otomatis setelah submit
// sukses, lihat submit() di bawah).
// ══════════════════════════════════════════════════════════════════════════════
class SensorInputNotifier extends StateNotifier<AsyncValue<void>> {
  final HomeRepository _repo;
  final Ref _ref;

  SensorInputNotifier(this._ref, this._repo)
    : super(const AsyncValue.data(null));

  Future<void> submit(SensorInputRequest input) async {
    state = const AsyncValue.loading();
    try {
      await _repo.inputSensor(input);
      state = const AsyncValue.data(null);
      // Data sensor baru masuk — refresh dashboard supaya langsung
      // menampilkan reading ini, dan buang hasil analisis lama (kalau
      // ada) karena itu berbasis data sensor yang sudah basi sekarang.
      _ref.invalidate(sensorProvider);
      _ref.read(analyzeProvider.notifier).reset();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      // Lempar ulang supaya form (SensorInputPage) bisa tampilkan pesan
      // error yang sama lewat try/catch lokalnya sendiri — konsisten
      // dengan pola ChatDetailNotifier.sendMessage().
      rethrow;
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

final sensorInputProvider =
    StateNotifierProvider.autoDispose<SensorInputNotifier, AsyncValue<void>>((
      ref,
    ) {
      return SensorInputNotifier(ref, ref.watch(homeRepositoryProvider));
    });