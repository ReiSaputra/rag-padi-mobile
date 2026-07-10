// lib/features/home/ui/widgets/sensor_input_page.dart
//
// Form input data sensor MANUAL — dipakai saat:
//   1. User baru belum pernah punya data sensor sama sekali (lihat empty
//      state di HomePage), atau
//   2. User mau update reading terbaru untuk lahannya sendiri (tombol
//      pensil di header "Data sensor" pada HomePage).
//
// Semua rentang nilai di validator SENGAJA disamakan persis dengan
// SensorInput di main.py (backend) — supaya user dapat feedback instan
// tanpa perlu round-trip ke server dulu. Ini VALIDASI SISI KLIEN untuk UX
// saja; backend tetap jadi satu-satunya sumber kebenaran (validasi client
// bisa dilewati orang yang memanggil API langsung), jadi kalau backend
// menolak dengan alasan lain (mis. rate limit 429, waktu di luar jendela),
// pesan errornya tetap ditampilkan apa adanya lewat apiErrorMessage().

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants.dart';
import '../../../../../core/api_error.dart';
import '../../data/home_models.dart';
import '../../providers/home_provider.dart';

class SensorInputPage extends ConsumerStatefulWidget {
  const SensorInputPage({super.key});

  @override
  ConsumerState<SensorInputPage> createState() => _SensorInputPageState();
}

class _SensorInputPageState extends ConsumerState<SensorInputPage> {
  final _formKey = GlobalKey<FormState>();

  // Wajib
  final _smCtrl = TextEditingController();
  final _sphCtrl = TextEditingController();
  final _snCtrl = TextEditingController();
  final _spCtrl = TextEditingController();
  final _skCtrl = TextEditingController();
  final _wtpCtrl = TextEditingController();
  final _wrfCtrl = TextEditingController();

  // Opsional
  final _whmCtrl = TextEditingController();
  final _wwsCtrl = TextEditingController();
  final _stCtrl = TextEditingController();
  final _scCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _smCtrl,
      _sphCtrl,
      _snCtrl,
      _spCtrl,
      _skCtrl,
      _wtpCtrl,
      _wrfCtrl,
      _whmCtrl,
      _wwsCtrl,
      _stCtrl,
      _scCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final input = SensorInputRequest(
      sm: _parse(_smCtrl.text)!,
      sph: _parse(_sphCtrl.text)!,
      sn: _parse(_snCtrl.text)!,
      sp: _parse(_spCtrl.text)!,
      sk: _parse(_skCtrl.text)!,
      wtp: _parse(_wtpCtrl.text)!,
      wrf: _parse(_wrfCtrl.text)!,
      whm: _whmCtrl.text.trim().isEmpty ? null : _parse(_whmCtrl.text),
      wws: _wwsCtrl.text.trim().isEmpty ? null : _parse(_wwsCtrl.text),
      st: _stCtrl.text.trim().isEmpty ? null : _parse(_stCtrl.text),
      sc: _scCtrl.text.trim().isEmpty ? null : _parse(_scCtrl.text),
    );

    try {
      await ref.read(sensorInputProvider.notifier).submit(input);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data sensor berhasil disimpan.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: kColorDanger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitting = ref.watch(sensorInputProvider) is AsyncLoading;

    return Scaffold(
      backgroundColor: kColorScaffold,
      appBar: AppBar(
        backgroundColor: kColorScaffold,
        elevation: 0,
        foregroundColor: kColorText,
        title: const Text(
          'Input Data Sensor',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(kPadPage, 8, kPadPage, 32),
            children: [
              const Text(
                'Masukkan hasil pembacaan sensor lahan kamu secara manual — '
                'misalnya saat perangkat IoT sedang tidak tersedia.',
                style: TextStyle(
                  fontSize: 13,
                  color: kColorTextMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              const Text('Kondisi Tanah', style: kStyleSectionTitle),
              const SizedBox(height: 12),
              _NumberField(
                controller: _smCtrl,
                label: 'Kelembaban Tanah',
                unit: '%',
                min: 0,
                max: 100,
                required: true,
              ),
              const SizedBox(height: 14),
              _NumberField(
                controller: _sphCtrl,
                label: 'pH Tanah',
                unit: '',
                min: 0,
                max: 14,
                required: true,
              ),
              const SizedBox(height: 14),
              _NumberField(
                controller: _snCtrl,
                label: 'Nitrogen',
                unit: 'mg/kg',
                min: 0,
                max: 1000,
                required: true,
              ),
              const SizedBox(height: 14),
              _NumberField(
                controller: _spCtrl,
                label: 'Fosfor',
                unit: 'mg/kg',
                min: 0,
                max: 1000,
                required: true,
              ),
              const SizedBox(height: 14),
              _NumberField(
                controller: _skCtrl,
                label: 'Kalium',
                unit: 'mg/kg',
                min: 0,
                max: 1000,
                required: true,
              ),

              const SizedBox(height: 24),
              const Text('Kondisi Cuaca', style: kStyleSectionTitle),
              const SizedBox(height: 12),
              _NumberField(
                controller: _wtpCtrl,
                label: 'Suhu Udara',
                unit: '°C',
                min: -10,
                max: 60,
                required: true,
                allowNegative: true,
              ),
              const SizedBox(height: 14),
              _NumberField(
                controller: _wrfCtrl,
                label: 'Curah Hujan',
                unit: 'mm',
                min: 0,
                max: 500,
                required: true,
              ),

              const SizedBox(height: 24),
              const Text('Data Tambahan (Opsional)', style: kStyleSectionTitle),
              const SizedBox(height: 4),
              const Text(
                'Boleh dikosongkan kalau belum tersedia.',
                style: kStyleMuted,
              ),
              const SizedBox(height: 12),
              _NumberField(
                controller: _whmCtrl,
                label: 'Kelembaban Udara',
                unit: '%',
                min: 0,
                max: 100,
                required: false,
              ),
              const SizedBox(height: 14),
              _NumberField(
                controller: _wwsCtrl,
                label: 'Kecepatan Angin',
                unit: 'm/s',
                min: 0,
                max: 150,
                required: false,
              ),
              const SizedBox(height: 14),
              _NumberField(
                controller: _stCtrl,
                label: 'Suhu Tanah',
                unit: '°C',
                min: -10,
                max: 60,
                required: false,
                allowNegative: true,
              ),
              const SizedBox(height: 14),
              _NumberField(
                controller: _scCtrl,
                label: 'Konduktivitas Tanah',
                unit: 'µS/cm',
                min: 0,
                max: 5000,
                required: false,
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kColorPrimaryMid,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: kColorPrimaryMid.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadius),
                    ),
                    elevation: 0,
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Simpan Data Sensor',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Input angka reusable ─────────────────────────────────────────────────────
class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unit;
  final double min;
  final double max;
  final bool required;
  final bool allowNegative;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.unit,
    required this.min,
    required this.max,
    required this.required,
    this.allowNegative = false,
  });

  String? _validate(String? v) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) {
      return required ? '$label wajib diisi.' : null;
    }
    final parsed = double.tryParse(text.replaceAll(',', '.'));
    if (parsed == null) return '$label harus berupa angka.';
    if (parsed < min || parsed > max) {
      return '$label harus di antara $min–$max${unit.isNotEmpty ? ' $unit' : ''}.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: kStyleSectionTitle.copyWith(fontSize: 14),
            children: [
              TextSpan(text: label),
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: kColorDanger),
                ),
              if (!required)
                const TextSpan(
                  text: '  (opsional)',
                  style: TextStyle(
                    color: kColorTextMuted,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(
            decimal: true,
            signed: allowNegative,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              allowNegative ? RegExp(r'[0-9.,\-]') : RegExp(r'[0-9.,]'),
            ),
          ],
          validator: _validate,
          decoration: InputDecoration(
            hintText: 'Rentang $min–$max',
            hintStyle: const TextStyle(color: kColorTextMuted, fontSize: 14),
            suffixText: unit.isNotEmpty ? unit : null,
            suffixStyle: const TextStyle(color: kColorTextMuted, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadius),
              borderSide: const BorderSide(color: kColorDivider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadius),
              borderSide: const BorderSide(color: kColorDivider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadius),
              borderSide: const BorderSide(color: kColorPrimary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadius),
              borderSide: const BorderSide(color: kColorDanger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadius),
              borderSide: const BorderSide(color: kColorDanger, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
