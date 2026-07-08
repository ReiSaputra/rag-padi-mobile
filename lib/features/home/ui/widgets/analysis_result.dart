// lib/features/home/ui/widgets/analysis_result.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants.dart';
import '../../data/home_models.dart';
import '../../../chat/data/chat_models.dart';
import '../../../chat/providers/chat_provider.dart';
import '../../../chat/ui/chat_detail_page.dart';

class AnalysisResult extends ConsumerStatefulWidget {
  final AnalyzeResult result;

  const AnalysisResult({super.key, required this.result});

  @override
  ConsumerState<AnalysisResult> createState() => _AnalysisResultState();
}

class _AnalysisResultState extends ConsumerState<AnalysisResult> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _controller.text.trim();
    if (msg.isEmpty || _sending) return;

    _controller.clear();
    setState(() => _sending = true);

    try {
      // BUG-005 (fixed): sebelumnya pesan user cuma ditempel manual ke
      // initialMessages tanpa pernah dikirim ke backend, jadi LLM tidak
      // pernah dipanggil dan tidak ada balasan baru yang ter-generate.
      //
      // Sekarang: muat konteks sesi analisis (jawaban awal /analyze) ke
      // chatDetailProvider, lalu benar-benar kirim pesan lewat sendMessage()
      // supaya backend memanggil LLM dan mengembalikan history lengkap
      // (termasuk balasan baru).
      final notifier = ref.read(chatDetailProvider.notifier);
      notifier.loadFromHistory(widget.result.sessionId, [
        ChatMessage(
          role: 'assistant',
          content: widget.result.jawaban,
          createdAt: widget.result.createdAt,
        ),
      ]);
      await notifier.sendMessage(msg);

      if (!mounted) return;
      final messages = ref.read(chatDetailProvider).value ?? [];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailPage(
            sessionId: widget.result.sessionId,
            preview: msg,
            createdAt: widget.result.createdAt,
            // Pakai history yang sudah lengkap (hasil sendMessage) supaya
            // ChatDetailPage tidak perlu fetch ulang ke server.
            initialMessages: messages,
          ),
        ),
      );
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
    return Container(
      decoration: BoxDecoration(
        color: kColorPrimary,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Teks jawaban LLM ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(kPadCard + 4),
            child: Text(
              widget.result.jawaban,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.6,
              ),
            ),
          ),

          // ── Divider tipis ─────────────────────────────────────────────────
          const Divider(color: Colors.white24, height: 1),

          // ── Input "Balas..." ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_sending,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _sending ? 'Mengirim...' : 'Balas...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
