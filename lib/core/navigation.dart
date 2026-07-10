// lib/core/navigation.dart
//
// GlobalKey Navigator + helper popToRoot().
//
// BUG FIX: sebelumnya logout (baik manual dari ProfilePage, maupun
// otomatis lewat ApiClient.onUnauthorized saat 401 — lihat BUG-015) hanya
// mengubah state authProvider, TANPA mengosongkan navigation stack.
//
// Akibatnya: kalau logout terjadi saat user sedang berada di halaman yang
// di-push di atas root (ProfilePage, ChatDetailPage, dst), _AuthGate di
// dasar stack memang sudah berganti ke LoginPage — tapi halaman yang
// ditumpuk di atasnya masih menutupi layar, jadi user tetap melihat
// halaman lama dan harus menekan tombol back manual dulu baru sampai ke
// LoginPage.
//
// navigatorKey ini dipasang di MaterialApp (lihat main.dart) supaya kode
// yang TIDAK punya BuildContext lokal — seperti AuthNotifier.logout() di
// auth_provider.dart, yang dipanggil dari mana saja termasuk dari
// callback ApiClient.onUnauthorized — tetap bisa mengosongkan stack
// navigasi kembali ke root.

import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Kembali ke route paling awal (root) di stack navigasi saat ini.
/// No-op (aman dipanggil) kalau memang sudah di root.
void popToRoot() {
  navigatorKey.currentState?.popUntil((route) => route.isFirst);
}
