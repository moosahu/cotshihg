import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class RatingPage extends StatefulWidget {
  final String bookingId;
  final String coachName;

  const RatingPage({
    super.key,
    required this.bookingId,
    required this.coachName,
  });

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage>
    with SingleTickerProviderStateMixin {
  int _selectedStars = 0;
  int _hoveredStars = 0;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedStars == 0) return;
    setState(() => _submitting = true);
    try {
      await getIt<ApiClient>().submitReview(
        widget.bookingId,
        _selectedStars,
        comment: _commentCtrl.text.trim(),
      );
      setState(() { _submitting = false; _submitted = true; });
      _animCtrl.forward();
      // Navigate to home after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go('/home');
    } catch (_) {
      setState(() => _submitting = false);
      if (mounted) context.go('/home');
    }
  }

  void _skip() => context.go('/home');

  String get _ratingLabel {
    switch (_selectedStars) {
      case 1: return 'سيئة';
      case 2: return 'مقبولة';
      case 3: return 'جيدة';
      case 4: return 'جيدة جداً';
      case 5: return 'ممتازة! 🎉';
      default: return 'اضغط على نجمة لتقييم جلستك';
    }
  }

  Color get _labelColor {
    switch (_selectedStars) {
      case 1: return Colors.red.shade400;
      case 2: return Colors.orange.shade400;
      case 3: return Colors.amber.shade600;
      case 4: return AppTheme.primaryColor;
      case 5: return AppTheme.successColor;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: _submitted ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: AppTheme.successColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 56),
            ),
            const SizedBox(height: 24),
            const Text(
              'شكراً على تقييمك!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'رأيك يساعدنا على تحسين تجربتك',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header
          const SizedBox(height: 32),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.star_rounded, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 24),
          const Text(
            'كيف كانت جلستك؟',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'جلسة مع ${widget.coachName}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 40),

          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starNum = i + 1;
              final filled = starNum <= (_hoveredStars > 0 ? _hoveredStars : _selectedStars);
              return GestureDetector(
                onTap: () => setState(() { _selectedStars = starNum; _hoveredStars = 0; }),
                onPanUpdate: (d) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  // approximate star width
                  final starWidth = 56.0;
                  final startX = (box.size.width - 5 * starWidth) / 2;
                  final pos = d.localPosition.dx - startX;
                  final hover = (pos / starWidth).ceil().clamp(1, 5);
                  setState(() => _hoveredStars = hover);
                },
                onPanEnd: (_) {
                  if (_hoveredStars > 0) {
                    setState(() { _selectedStars = _hoveredStars; _hoveredStars = 0; });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: filled ? 52 : 44,
                    color: filled ? Colors.amber : Colors.grey.shade300,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // Label
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _ratingLabel,
              key: ValueKey(_selectedStars),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _labelColor,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Comment
          TextField(
            controller: _commentCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'أضف تعليقاً (اختياري)...',
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (_selectedStars > 0 && !_submitting) ? _submit : null,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('إرسال التقييم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),

          // Skip
          TextButton(
            onPressed: _skip,
            child: const Text(
              'تخطي',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
