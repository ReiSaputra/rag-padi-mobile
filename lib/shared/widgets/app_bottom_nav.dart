// lib/shared/widgets/app_bottom_nav.dart
//
// AppBottomNav — satu widget bottom navigation yang dipakai bersama di
// HomePage, ChatListPage, dan ChatDetailPage.
//
// FIX (konsolidasi BUG-016): sebelumnya ada 3 class `_BottomNav` privat
// yang terpisah (copy-paste) di masing-masing file. Akibatnya perbaikan
// navigasi di satu tab (misal BUG-009: tab Profil) tidak otomatis ikut ke
// file lain — harus diperbaiki manual di 3 tempat (itulah asal BUG-016).
// Sekarang satu widget ini dipakai di mana pun bottom nav dibutuhkan,
// jadi perubahan navigasi cukup dilakukan sekali di sini.
//
// CATATAN DESAIN: widget ini SENGAJA tidak meng-import ChatListPage /
// ProfilePage secara langsung (yang akan membuat circular import karena
// kedua halaman itu juga meng-import widget ini). Navigasi antar tab
// dilakukan lewat named routes ('/chat', '/profile') yang didaftarkan di
// MaterialApp (lihat main.dart) — widget ini cukup tahu NAMA rute, bukan
// implementasi halamannya.

import 'package:flutter/material.dart';
import '../../core/constants.dart';

enum AppTab { beranda, chat, profil }

class AppBottomNav extends StatelessWidget {
  /// Tab yang sedang aktif di halaman saat ini.
  final AppTab current;

  const AppBottomNav({super.key, required this.current});

  void _goTo(BuildContext context, AppTab target) {
    if (target == current) return; // sudah di tab ini, tidak perlu apa-apa

    // Selalu kembali ke root (Home) dulu sebelum push tab baru. Ini
    // mencegah stack menumpuk halaman yang sama berkali-kali kalau user
    // bolak-balik pindah tab dari kedalaman stack yang berbeda-beda —
    // misalnya ChatDetailPage bisa dibuka dari ChatListPage ATAU langsung
    // dari AnalysisResult di HomePage, jadi kedalaman stack-nya tidak
    // selalu sama.
    Navigator.of(context).popUntil((route) => route.isFirst);

    switch (target) {
      case AppTab.beranda:
        break; // sudah di root (Home) setelah popUntil di atas
      case AppTab.chat:
        Navigator.of(context).pushNamed('/chat');
        break;
      case AppTab.profil:
        Navigator.of(context).pushNamed('/profile');
        break;
    }
  }

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
                isActive: current == AppTab.beranda,
                onTap: () => _goTo(context, AppTab.beranda),
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Chat',
                isActive: current == AppTab.chat,
                onTap: () => _goTo(context, AppTab.chat),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profil',
                isActive: current == AppTab.profil,
                onTap: () => _goTo(context, AppTab.profil),
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
