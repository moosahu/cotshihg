import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

// DEV MODE: set to false in production
const bool kDevMode = false;

class _Country {
  final String flag;
  final String name;
  final String code;
  const _Country(this.flag, this.name, this.code);
}

const List<_Country> _countries = [
  _Country('🇸🇦', 'السعودية', '+966'),
  _Country('🇦🇪', 'الإمارات', '+971'),
  _Country('🇰🇼', 'الكويت', '+965'),
  _Country('🇧🇭', 'البحرين', '+973'),
  _Country('🇶🇦', 'قطر', '+974'),
  _Country('🇴🇲', 'عُمان', '+968'),
  _Country('🇯🇴', 'الأردن', '+962'),
  _Country('🇪🇬', 'مصر', '+20'),
  _Country('🇱🇧', 'لبنان', '+961'),
  _Country('🇮🇶', 'العراق', '+964'),
  _Country('🇾🇪', 'اليمن', '+967'),
  _Country('🇸🇾', 'سوريا', '+963'),
  _Country('🇲🇦', 'المغرب', '+212'),
  _Country('🇩🇿', 'الجزائر', '+213'),
  _Country('🇹🇳', 'تونس', '+216'),
];

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  _Country _selectedCountry = _countries.first;

  void _pickCountry() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text('اختر الدولة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _countries.length,
              itemBuilder: (_, i) {
                final c = _countries[i];
                return ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                  title: Text(c.name),
                  trailing: Text(c.code, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  onTap: () {
                    setState(() => _selectedCountry = c);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    // DEV MODE: skip OTP verification
    if (kDevMode) {
      context.go('/complete-profile');
      return;
    }

    setState(() => _isLoading = true);
    final phone = '${_selectedCountry.code}${_phoneController.text.trim()}';

    try {
      if (Platform.isIOS) {
        // The flutter firebase_auth plugin always passes UIDelegate:nil to the
        // native Firebase SDK, which causes a fatal crash on iOS 13+ when APNs
        // is unavailable and Firebase falls back to reCAPTCHA.
        // Fix: call our native method channel that passes a proper UIDelegate.
        const channel = MethodChannel('firebase_auth_ios_helper');
        final verificationId = await channel.invokeMethod<String>(
          'verifyPhoneNumber',
          {'phoneNumber': phone},
        );
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (verificationId != null && verificationId.isNotEmpty) {
          context.go('/otp', extra: {
            'phone': phone,
            'verificationId': verificationId,
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل إرسال رمز التحقق'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } else {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (PhoneAuthCredential credential) async {
            try {
              final userCredential =
                  await FirebaseAuth.instance.signInWithCredential(credential);
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
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'فشل إرسال رمز التحقق'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
                // Phone field with country picker
                FormField<String>(
                  validator: (_) {
                    final v = _phoneController.text;
                    if (v.isEmpty) return 'أدخل رقم الجوال';
                    if (v.length < 7) return 'رقم غير صحيح';
                    return null;
                  },
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: field.hasError
                                  ? AppTheme.errorColor
                                  : Colors.grey.shade400,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              // Country code picker
                              GestureDetector(
                                onTap: _pickCountry,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(color: Colors.grey.shade300),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_selectedCountry.flag, style: const TextStyle(fontSize: 20)),
                                      const SizedBox(width: 6),
                                      Text(
                                        _selectedCountry.code,
                                        style: const TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                              // Phone number input
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  textDirection: TextDirection.ltr,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  onChanged: (_) => field.didChange(_phoneController.text),
                                  decoration: const InputDecoration(
                                    hintText: '5XXXXXXXX',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (field.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 12),
                          child: Text(
                            field.errorText!,
                            style: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
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
