// lib/features/home/data/home_models.dart

// ── Sensor ────────────────────────────────────────────────────────────────────
class SensorData {
  final int id;
  final double sm;
  final double sph;
  final double sn;
  final double sp;
  final double sk;
  final double wtp;
  final double wrf;
  final double? whm;
  final double? wws;
  final double? st;
  final double? sc;
  final String time;

  const SensorData({
    required this.id,
    required this.sm,
    required this.sph,
    required this.sn,
    required this.sp,
    required this.sk,
    required this.wtp,
    required this.wrf,
    this.whm,
    this.wws,
    this.st,
    this.sc,
    required this.time,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) => SensorData(
    id: json['id'] as int,
    sm: (json['sm'] as num).toDouble(),
    sph: (json['sph'] as num).toDouble(),
    sn: (json['sn'] as num).toDouble(),
    sp: (json['sp'] as num).toDouble(),
    sk: (json['sk'] as num).toDouble(),
    wtp: (json['wtp'] as num).toDouble(),
    wrf: (json['wrf'] as num).toDouble(),
    whm: (json['whm'] as num?)?.toDouble(),
    wws: (json['wws'] as num?)?.toDouble(),
    st: (json['st'] as num?)?.toDouble(),
    sc: (json['sc'] as num?)?.toDouble(),
    time: json['time'] as String,
  );
}

// ── Analyze Result ────────────────────────────────────────────────────────────
class AnalyzeResult {
  final String sessionId;
  final String jawaban;
  final String sensorParsed;
  final double retrievalTimeMs;
  final String createdAt;

  const AnalyzeResult({
    required this.sessionId,
    required this.jawaban,
    required this.sensorParsed,
    required this.retrievalTimeMs,
    required this.createdAt,
  });

  factory AnalyzeResult.fromJson(Map<String, dynamic> json) => AnalyzeResult(
    sessionId: json['session_id'] as String,
    jawaban: json['jawaban'] as String,
    sensorParsed: json['sensor_parsed'] as String,
    retrievalTimeMs: (json['retrieval_time_ms'] as num).toDouble(),
    createdAt: json['created_at'] as String,
  );
}

// ── History Item ──────────────────────────────────────────────────────────────
class HistoryItem {
  final String sessionId;
  final String createdAt;
  final String preview;
  final int messageCount;
  final String type; // 'analisis' | 'tanya_jawab'

  const HistoryItem({
    required this.sessionId,
    required this.createdAt,
    required this.preview,
    required this.messageCount,
    required this.type,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    sessionId: json['session_id'] as String,
    createdAt: json['created_at'] as String,
    preview: json['preview'] as String,
    messageCount: json['message_count'] as int,
    type: json['type'] as String,
  );
}
