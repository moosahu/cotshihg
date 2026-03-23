import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../bloc/auth_bloc.dart';
import '../../../../core/theme/app_theme.dart';

class OtpPage extends StatefulWidget {
  final String phone;
  final String verificationId;
  final String? autoToken;

  const OtpPage({
    super.key,
    required this.phone,
    required this.verificationId,
    this.autoToken,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> with WidgetsBindingObserver {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _secondsLeft = 60;
  Timer? _timer;
  Timer? _clipboardTimer; // periodic clipboard checker
  bool _isVerifying = false;
  String? _currentVerificationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentVerificationId = widget.verificationId;
    _startTimer();

    // Auto-verified on Android — process immediately
    if (widget.autoToken != null && widget.autoToken!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AuthBloc>().add(
          VerifyOTPEvent(firebaseToken: widget.autoToken!, phone: widget.phone),
        );
      });
    }

    // Check clipboard on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboard();
      _startClipboardTimer();
    });

    // Listen to each focus node — check clipboard when field is focused
    for (int i = 0; i < 6; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) _checkClipboard();
      });
    }
  }

  // Called when app returns to foreground (user switched to SMS app and came back)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  void _startClipboardTimer() {
    _clipboardTimer?.cancel();
    // Check every 2 seconds until OTP is filled
    _clipboardTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_otp.length == 6 || _isVerifying) {
        _clipboardTimer?.cancel();
        return;
      }
      _checkClipboard();
    });
  }

  /// Checks clipboard for a 6-digit code and fills automatically
  Future<void> _checkClipboard() async {
    if (_isVerifying) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.replaceAll(RegExp(r'\D'), '') ?? '';
      if (text.length == 6) {
        _fillOtp(text);
      }
    } catch (_) {}
  }

  /// Distributes 6 digits across all boxes and auto-verifies
  void _fillOtp(String digits) {
    if (digits.length < 6) return;
    _clipboardTimer?.cancel(); // stop polling once filled
    for (int i = 0; i < 6; i++) {
      _controllers[i].text = digits[i];
    }
    _focusNodes[5].requestFocus();
    setState(() {});
    // Small delay so UI updates before verifying
    Future.delayed(const Duration(milliseconds: 100), _verify);
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _clipboardTimer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onChanged(String val, int index) {
    // Paste detection: value longer than 1 digit
    if (val.length > 1) {
      final digits = val.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 6) {
        // Full code pasted — fill all boxes from start
        _fillOtp(digits);
      } else {
        // Partial paste — fill from current box onward
        int pos = index;
        for (final ch in digits.characters) {
          if (pos < 6) {
            _controllers[pos].text = ch;
            pos++;
          }
        }
        if (pos < 6) _focusNodes[pos].requestFocus();
        setState(() {});
        if (_otp.length == 6) _verify();
      }
      return;
    }

    // Normal single-digit input
    if (val.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (val.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_otp.length == 6) _verify();
  }

  Future<void> _verify() async {
    if (_isVerifying || _otp.length < 6) return;
    setState(() => _isVerifying = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId!,
        smsCode: _otp,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();

      if (idToken != null && mounted) {
        context.read<AuthBloc>().add(
          VerifyOTPEvent(firebaseToken: idToken, phone: widget.phone),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.code == 'invalid-verification-code'
                ? 'رمز التحقق غير صحيح'
                : e.message ?? 'خطأ Firebase: ${e.code}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _resendOTP() async {
    setState(() => _isVerifying = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        final userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
        final idToken = await userCredential.user?.getIdToken();
        if (idToken != null && mounted) {
          context.read<AuthBloc>().add(
            VerifyOTPEvent(firebaseToken: idToken, phone: widget.phone),
          );
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          setState(() => _isVerifying = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message ?? 'فشل إعادة الإرسال'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          setState(() {
            _currentVerificationId = verificationId;
            _isVerifying = false;
          });
          _startTimer();
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التحقق من الرقم')),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            final user = state.user;
            final isNewUser = user['name'] == null || (user['name'] as String).isEmpty;
            if (isNewUser) {
              context.go('/complete-profile');
            } else {
              final role = user['role'] as String? ?? 'client';
              context.go((role == 'coach' || role == 'therapist') ? '/coach/dashboard' : '/home');
            }
          } else if (state is AuthError) {
            setState(() => _isVerifying = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.sms_outlined, size: 72, color: AppTheme.primaryColor),
              const SizedBox(height: 24),
              const Text(
                'أدخل رمز التحقق',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'أرسلنا رمزاً مكوناً من 6 أرقام إلى\n${widget.phone}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 40),
              // OTP boxes — LTR so digits flow left to right
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (i) => SizedBox(
                    width: 48,
                    height: 56,
                    child: TextField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      enabled: !_isVerifying,
                      // No maxLength — allows paste detection in onChanged
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                        filled: _controllers[i].text.isNotEmpty,
                        fillColor: AppTheme.primaryColor.withOpacity(0.06),
                      ),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      onChanged: (v) => _onChanged(v, i),
                    ),
                  )),
                ),
              ),
              const SizedBox(height: 16),
              // Paste button
              TextButton.icon(
                onPressed: _isVerifying ? null : _checkClipboard,
                icon: const Icon(Icons.content_paste_rounded, size: 16),
                label: const Text('لصق الرمز من الحافظة'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
              ),
              const SizedBox(height: 16),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final loading = _isVerifying || state is AuthLoading;
                  if (loading) {
                    return Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          'جاري التحقق...',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    );
                  }
                  return ElevatedButton(
                    onPressed: _otp.length == 6 ? _verify : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: const Text('تحقق'),
                  );
                },
              ),
              const SizedBox(height: 24),
              _secondsLeft > 0
                  ? Text(
                      'إعادة الإرسال بعد $_secondsLeft ثانية',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    )
                  : TextButton(
                      onPressed: _isVerifying ? null : _resendOTP,
                      child: const Text('إعادة إرسال الرمز'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
