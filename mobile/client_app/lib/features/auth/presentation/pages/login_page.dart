import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

// DEV MODE: set to false in production
const bool kDevMode = false;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    // DEV MODE: skip OTP verification
    if (kDevMode) {
      context.go('/complete-profile');
      return;
    }

    setState(() => _isLoading = true);
    final phone = '+966${_phoneController.text.trim()}';

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verification on Android — sign in automatically
        try {
          final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
          final idToken = await userCredential.user?.getIdToken();
          if (mounted && idToken != null) {
            context.go('/otp', extra: {
              'phone': phone,
              'verificationId': '',
              'autoToken': idToken,
            });
          }
        } catch (_) {}
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message ?? 'فشل إرسال رمز التحقق'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          setState(() => _isLoading = false);
          context.go('/otp', extra: {
            'phone': phone,
            'verificationId': verificationId,
          });
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                const Icon(Icons.psychology, size: 80, color: AppTheme.primaryColor),
                const SizedBox(height: 32),
                const Text(
                  'مرحباً بك',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'أدخل رقم جوالك للمتابعة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'رقم الجوال',
                    prefixText: '+966 ',
                    hintText: '5XXXXXXXX',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'أدخل رقم الجوال';
                    if (v.length < 9) return 'رقم غير صحيح';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendOTP,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('إرسال رمز التحقق'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
