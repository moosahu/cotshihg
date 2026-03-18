import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/network/api_client.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  String? _verificationId;

  Future<void> _sendOTP() async {
    final phone = '+966${_phoneController.text.trim()}';
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _loading = false);
          _showError(e.message ?? 'فشل التحقق');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _loading = false;
          });
        },
        codeAutoRetrievalTimeout: (_) {},
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() => _loading = false);
      _showError(e.toString());
    }
  }

  Future<void> _verifyOTP() async {
    if (_verificationId == null) return;
    setState(() => _loading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      await _signInWithCredential(credential);
    } catch (e) {
      setState(() => _loading = false);
      _showError('رمز التحقق غير صحيح');
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
    final firebaseToken = await userCred.user!.getIdToken();
    final phone = '+966${_phoneController.text.trim()}';
    final res = await getIt<ApiClient>().verifyOTP(firebaseToken!, phone);
    final data = res['data'] as Map<String, dynamic>;
    await getIt<StorageService>().saveToken(data['token'] as String);
    await getIt<StorageService>().saveUser(jsonEncode(data['user']));
    if (mounted) context.go('/dashboard');
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Icon(Icons.psychology, size: 80, color: Colors.white),
              const SizedBox(height: 16),
              const Text('Coaching', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              const Text('بوابة الكوتش', style: TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Cairo')),
              const SizedBox(height: 48),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_otpSent ? 'أدخل رمز التحقق' : 'تسجيل الدخول',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      if (!_otpSent) ...[
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: 'رقم الجوال',
                            prefixText: '+966 ',
                            filled: true,
                            fillColor: AppTheme.backgroundColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ] else ...[
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: 'رمز التحقق (6 أرقام)',
                            filled: true,
                            fillColor: AppTheme.backgroundColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loading ? null : (_otpSent ? _verifyOTP : _sendOTP),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                        child: _loading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_otpSent ? 'تحقق' : 'إرسال رمز التحقق'),
                      ),
                      if (_otpSent) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() { _otpSent = false; _otpController.clear(); }),
                          child: const Text('تغيير الرقم'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Center(
                        child: Text('للانضمام ككوتش، تواصل معنا على\nsupport@coaching.app',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ),
                    ],
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
