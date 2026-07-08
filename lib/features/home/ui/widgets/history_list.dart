// lib/features/home/ui/widgets/history_list.dart

import 'package:flutter/material.dart';
import '../../../../core/constants.dart';
import '../../data/home_models.dart';
import '../../../chat/ui/chat_detail_page.dart';

class HistoryList extends StatelessWidget {
  final List<HistoryItem> items;

  const HistoryList({super.key, required this.items});

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

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: const Text(
          'Belum ada histori percakapan.',
          style: TextStyle(color: kColorTextMuted, fontSize: 13),
        ),
      );
    }

    return Column(
      children: items
          .map((item) => _HistoryCard(item: item, formatDate: _formatDate))
          .toList(),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryItem item;
  final String Function(String) formatDate;

  const _HistoryCard({required this.item, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailPage(
              sessionId: item.sessionId,
              preview: item.preview.isNotEmpty ? item.preview : 'Percakapan',
              createdAt: formatDate(item.createdAt),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
