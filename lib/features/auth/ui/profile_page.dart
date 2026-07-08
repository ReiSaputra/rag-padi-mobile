// lib/features/auth/ui/profile_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../data/auth_models.dart';
import '../providers/auth_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _showPasswordSection = false;

  bool _loadingInfo = true;
  bool _saving = false;
  bool _changingPassword = false;
  UserInfo? _userInfo;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingInfo = true;
      _loadError = null;
    });
    try {
      final info = await ref.read(authRepositoryProvider).me();
      if (!mounted) return;
      setState(() {
        _userInfo = info;
        _nameCtrl.text = info.name;
        _emailCtrl.text = info.email;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingInfo = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await ref
          .read(authProvider.notifier)
          .updateProfile(
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui.')),
      );
      await _loadProfile();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('409')
          ? 'Email sudah digunakan oleh akun lain.'
          : 'Gagal memperbarui profil. Periksa koneksi kamu.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: kColorDanger),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _changingPassword = true);

    try {
      await ref
          .read(authProvider.notifier)
          .updateProfile(
            currentPassword: _currentPassCtrl.text,
            newPassword: _newPassCtrl.text,
          );
      if (!mounted) return;
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      setState(() => _showPasswordSection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diubah.')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('401')
          ? 'Password saat ini salah.'
          : 'Gagal mengubah password. Periksa koneksi kamu.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: kColorDanger),
      );
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLarge),
        ),
        title: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Kamu yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: kColorTextMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kColorDanger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kRadius),
              ),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const bulan = [
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
      ];
      return '${dt.day} ${bulan[dt.month]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kColorTextMuted, fontSize: 14),
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorScaffold,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: const BoxDecoration(
                color: kColorSurface,
                border: Border(bottom: BorderSide(color: kColorDivider)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: kColorText),
                  ),
                  const Text(
                    'Profil',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kColorText,
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: _loadingInfo
                  ? const Center(
                      child: CircularProgressIndicator(color: kColorPrimary),
                    )
                  : _loadError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(kPadPage),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Gagal memuat profil.\n$_loadError',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: kColorTextMuted),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kColorPrimary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Coba lagi'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(kPadPage),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Avatar + ringkasan ────────────────────────
                          Center(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: kColorPrimary,
                                  child: Text(
                                    (_userInfo?.name.isNotEmpty ?? false)
                                        ? _userInfo!.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _userInfo?.name ?? '-',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: kColorText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _userInfo?.email ?? '-',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: kColorTextMuted,
                                  ),
                                ),
                                if (_userInfo != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Bergabung sejak ${_formatDate(_userInfo!.createdAt)}',
                                    style: kStyleMuted,
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Form Edit Profil ──────────────────────────
                          const Text('Edit Profil', style: kStyleSectionTitle),
                          const SizedBox(height: 12),
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nama Lengkap',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: kColorText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nameCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: _inputDecoration('Nama kamu'),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Nama wajib diisi.';
                                    }
                                    if (v.trim().length < 2) {
                                      return 'Nama terlalu pendek.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Email',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: kColorText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _inputDecoration(
                                    'contoh@email.com',
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Email wajib diisi.';
                                    }
                                    if (!v.contains('@')) {
                                      return 'Format email tidak valid.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _saving ? null : _saveProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kColorPrimaryMid,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: kColorPrimaryMid
                                          .withOpacity(0.6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          kRadius,
                                        ),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _saving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Simpan Perubahan',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),
                          const Divider(color: kColorDivider),
                          const SizedBox(height: 12),

                          // ── Ubah Password (collapsible) ───────────────
                          InkWell(
                            onTap: () => setState(
                              () => _showPasswordSection =
                                  !_showPasswordSection,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Ubah Password',
                                  style: kStyleSectionTitle,
                                ),
                                Icon(
                                  _showPasswordSection
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: kColorTextMuted,
                                ),
                              ],
                            ),
                          ),
                          if (_showPasswordSection) ...[
                            const SizedBox(height: 12),
                            Form(
                              key: _passwordFormKey,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    controller: _currentPassCtrl,
                                    obscureText: _obscureCurrent,
                                    decoration:
                                        _inputDecoration('Password saat ini')
                                            .copyWith(
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                  _obscureCurrent
                                                      ? Icons
                                                            .visibility_outlined
                                                      : Icons
                                                            .visibility_off_outlined,
                                                  color: kColorTextMuted,
                                                ),
                                                onPressed: () => setState(
                                                  () => _obscureCurrent =
                                                      !_obscureCurrent,
                                                ),
                                              ),
                                            ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Password saat ini wajib diisi.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _newPassCtrl,
                                    obscureText: _obscureNew,
                                    decoration:
                                        _inputDecoration(
                                          'Password baru (min. 8 karakter)',
                                        ).copyWith(
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscureNew
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                        .visibility_off_outlined,
                                              color: kColorTextMuted,
                                            ),
                                            onPressed: () => setState(
                                              () =>
                                                  _obscureNew = !_obscureNew,
                                            ),
                                          ),
                                        ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Password baru wajib diisi.';
                                      }
                                      if (v.length < 8) {
                                        return 'Password minimal 8 karakter.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _confirmPassCtrl,
                                    obscureText: _obscureConfirm,
                                    decoration:
                                        _inputDecoration(
                                          'Ulangi password baru',
                                        ).copyWith(
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscureConfirm
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                        .visibility_off_outlined,
                                              color: kColorTextMuted,
                                            ),
                                            onPressed: () => setState(
                                              () => _obscureConfirm =
                                                  !_obscureConfirm,
                                            ),
                                          ),
                                        ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Konfirmasi password wajib diisi.';
                                      }
                                      if (v != _newPassCtrl.text) {
                                        return 'Password tidak cocok.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _changingPassword
                                          ? null
                                          : _changePassword,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kColorPrimaryMid,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor:
                                            kColorPrimaryMid.withOpacity(0.6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            kRadius,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: _changingPassword
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: Colors.white,
                                                  ),
                                            )
                                          : const Text(
                                              'Ubah Password',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 28),
                          const Divider(color: kColorDivider),
                          const SizedBox(height: 20),

                          // ── Logout ─────────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _showLogoutDialog,
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: kColorDanger,
                              ),
                              label: const Text(
                                'Keluar',
                                style: TextStyle(
                                  color: kColorDanger,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: kColorDanger),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    kRadius,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}