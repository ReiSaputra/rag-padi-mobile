import 'package:flutter/material.dart';
import '../../../../core/constants.dart';
import '../../data/home_models.dart';

// Status enum
enum SensorStatus { bagus, netral, kritis }

extension SensorStatusColor on SensorStatus {
  Color get bg => switch (this) {
    SensorStatus.bagus => kColorBgGreen,
    SensorStatus.netral => kColorBgNeutral,
    SensorStatus.kritis => kColorBgDanger,
  };

  Color get iconColor => switch (this) {
    SensorStatus.bagus => kColorPrimaryLight,
    SensorStatus.netral => kColorNeutral,
    SensorStatus.kritis => kColorDanger,
  };

  Color get valueColor => switch (this) {
    SensorStatus.bagus => kColorPrimary,
    SensorStatus.netral => kColorText,
    SensorStatus.kritis => kColorDanger,
  };

  Color get border => switch (this) {
    SensorStatus.bagus => const Color(0xFFA5D6A7),
    SensorStatus.netral => kColorDivider,
    SensorStatus.kritis => kColorBgDangerBorder,
  };
}

// Helper: tentukan status tiap field
SensorStatus smStatus(double v) {
  if (v >= 80) return SensorStatus.bagus; // optimal
  if (v >= 40) return SensorStatus.netral; // perlu monitor / segera siram
  return SensorStatus.kritis; // darurat, siram 5-8L
}
// Tidak berubah — breakpoint (40, 80) sudah cocok dengan rag.py.

SensorStatus sphStatus(double v) {
  if (v >= 5.5 && v <= 8.2) return SensorStatus.bagus; // S1, sangat sesuai
  if (v >= 5.0 && v < 5.5) return SensorStatus.netral; // S2, cukup sesuai
  if (v > 8.2 && v <= 8.5)
    return SensorStatus.netral; // zona abu-abu (tak ada di rag.py)
  return SensorStatus.kritis; // <5.0 atau >8.5, tidak sesuai
}
// BUG LAMA: v >= 5.0 tanpa batas atas ikut menangkap pH tinggi (mis. 9.0)
// dan menandainya "netral", padahal rag.py bilang >8.5 = tidak sesuai (kritis).

SensorStatus wtpStatus(double v) {
  if (v >= 22 && v <= 28) return SensorStatus.bagus; // optimal vegetatif
  if (v >= 20 && v <= 32)
    return SensorStatus.netral; // masih diterima / mendekati optimal
  return SensorStatus
      .kritis; // <20 (melambat) atau >32 (mulai terganggu s/d stres berat)
}
// Disederhanakan dari 6 tingkat rag.py jadi 3 tingkat, tapi batas kritis
// sekarang konsisten dengan titik ">32 = mulai terganggu".

SensorStatus wrfStatus(double v) {
  if (v > 5) return SensorStatus.bagus;
  if (v >= 2) return SensorStatus.netral;
  return SensorStatus.kritis;
}
// Tidak berubah — breakpoint (2, 5) sudah cocok dengan rag.py.

SensorStatus snStatus(double v) {
  if (v >= 150 && v <= 250) return SensorStatus.bagus; // optimal
  if (v >= 50 && v <= 300)
    return SensorStatus.netral; // cukup awal / zona transisi
  return SensorStatus
      .kritis; // <50 defisiensi ATAU >300 kelebihan (rentan hama/blast)
}
// BUG LAMA: v >= 50 tanpa batas atas ikut menangkap N berlebih (>300)
// dan menandainya "netral", padahal rag.py bilang itu rentan hama & blast.

SensorStatus spStatus(double v) {
  if (v >= 87 && v <= 174)
    return SensorStatus.bagus; // status P sedang, dosis 75kg
  if (v > 174)
    return SensorStatus.netral; // status P tinggi, dosis lebih rendah (50kg)
  return SensorStatus.kritis; // <87, status P rendah, dosis 100kg
}
// Breakpoint lama (50) tidak ada sama sekali di rag.py — diganti pakai
// breakpoint asli (87, 174).

SensorStatus skStatus(double v) {
  if (v >= 83 && v <= 166)
    return SensorStatus.bagus; // status K sedang, dosis 50kg
  if (v > 166) return SensorStatus.netral; // status K tinggi, dosis sama (50kg)
  return SensorStatus.kritis; // <83, status K rendah, dosis 100kg
}
// Sama seperti sp — breakpoint 50 lama dihapus, dipakai breakpoint asli (83, 166).

// Main widget: SensorGrid
class SensorGrid extends StatelessWidget {
  final SensorData sensor;

  const SensorGrid({super.key, required this.sensor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Card besar: Kelembaban Tanah
        _SensorCardLarge(
          icon: Icons.water_drop_outlined,
          value: '${sensor.sm.toStringAsFixed(1)}%',
          label: 'Kelembaban Tanah',
          status: smStatus(sensor.sm),
        ),
        const SizedBox(height: 8),
        // Row 1: pH, Suhu, Curah Hujan
        Row(
          children: [
            Expanded(
              child: _SensorCardSmall(
                icon: Icons.science_outlined,
                value: sensor.sph.toStringAsFixed(1),
                label: 'pH Tanah',
                status: sphStatus(sensor.sph),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SensorCardSmall(
                icon: Icons.thermostat_outlined,
                value: '${sensor.wtp.toStringAsFixed(1)}°C',
                label: 'Suhu Udara',
                status: wtpStatus(sensor.wtp),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SensorCardSmall(
                icon: Icons.grain_outlined,
                value: '${sensor.wrf.toStringAsFixed(1)}',
                label: 'Curah Hujan',
                status: wrfStatus(sensor.wrf),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: Nitrogen, Fosfor, Kalium
        Row(
          children: [
            Expanded(
              child: _SensorCardSmall(
                icon: Icons.eco_outlined,
                value: '${sensor.sn.toStringAsFixed(1)}',
                label: 'Nitrogen',
                status: snStatus(sensor.sn),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SensorCardSmall(
                icon: Icons.eco_outlined,
                value: '${sensor.sp.toStringAsFixed(1)}',
                label: 'Fosfor',
                status: spStatus(sensor.sp),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SensorCardSmall(
                icon: Icons.eco_outlined,
                value: '${sensor.sk.toStringAsFixed(1)}',
                label: 'Kalium',
                status: skStatus(sensor.sk),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Legenda
        Row(
          children: [
            _LegendDot(color: kColorPrimaryLight, label: '= Bagus'),
            const SizedBox(width: 12),
            _LegendDot(color: kColorNeutral, label: '= Netral'),
            const SizedBox(width: 12),
            _LegendDot(color: kColorDanger, label: '= Kritis'),
          ],
        ),
      ],
    );
  }
}

// Card Besar
class _SensorCardLarge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final SensorStatus status;

  const _SensorCardLarge({
    required this.icon,
    required this.value,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: status.border, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: status.iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: kStyleCardValue.copyWith(
              color: status.valueColor,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: kStyleCardLabel),
        ],
      ),
    );
  }
}

// Card Kecil
class _SensorCardSmall extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final SensorStatus status;

  const _SensorCardSmall({
    required this.icon,
    required this.value,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: status.border, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: status.iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: kStyleCardValue.copyWith(
              color: status.valueColor,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: kStyleCardLabel, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// Legenda dot
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: kStyleMuted),
      ],
    );
  }
}
