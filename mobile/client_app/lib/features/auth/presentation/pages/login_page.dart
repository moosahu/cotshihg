import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';
import '../../../../core/theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

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
                BlocConsumer<AuthBloc, AuthState>(
                  listener: (context, state) {
                    if (state is OTPSent) {
                      context.go('/otp', extra: '+966${_phoneController.text}');
                    } else if (state is AuthError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.message), backgroundColor: AppTheme.errorColor),
                      );
                    }
                  },
                  builder: (context, state) {
                    return ElevatedButton(
                      onPressed: state is AuthLoading ? null : () {
                        if (_formKey.currentState!.validate()) {
                          context.read<AuthBloc>().add(
                            SendOTPEvent(phone: '+966${_phoneController.text}'),
                          );
                        }
                      },
                      child: state is AuthLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('إرسال رمز التحقق'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
