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
