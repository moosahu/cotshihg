import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../di/injection.dart';
import '../network/api_client.dart';

Future<void> showAnnouncementIfActive(BuildContext context) async {
  try {
    final data = await getIt<ApiClient>().getActiveAnnouncement();
    if (data == null) return;
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AnnouncementDialog(data: data),
    );
  } catch (_) {}
}

class _AnnouncementDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AnnouncementDialog({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String?;
    final imageUrl = data['image_url'] as String?;
    final buttonText = data['button_text'] as String?;
    final buttonUrl = data['button_url'] as String?;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Close button row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20, color: AppTheme.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                if (body != null && body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
                  ),
                ],
                if (buttonText != null && buttonText.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        if (buttonUrl != null && buttonUrl.isNotEmpty) {
                          final uri = Uri.tryParse(buttonUrl);
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                      child: Text(buttonText),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
