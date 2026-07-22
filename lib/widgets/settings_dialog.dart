import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:asko_pdf/services/settings_service.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  int _category = 0;
  final _settings = SettingsService();
  bool _copyPageAsImageEnabled = true;

  @override
  void initState() {
    super.initState();
    _settings.getCopyPageAsImageEnabled().then((v) {
      if (mounted) setState(() => _copyPageAsImageEnabled = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    const categories = [
      ('View', Icons.visibility_outlined),
      ('About', Icons.info_outline),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 600,
        height: 450,
        child: Row(
          children: [
            Container(
              width: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  for (var i = 0; i < categories.length; i++)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _category = i),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _category == i
                                ? primary.withValues(alpha: 0.1)
                                : null,
                            border: Border(
                              left: BorderSide(
                                color: _category == i
                                    ? primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                categories[i].$2,
                                size: 20,
                                color: _category == i
                                    ? primary
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                categories[i].$1,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _category == i
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: _category == i
                                      ? primary
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.grey.shade600),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: _category == 0 ? _buildView() : _buildAbout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'View Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                Icons.content_copy_rounded,
                color: Theme.of(context).primaryColor,
              ),
              title: const Text(
                'Copy page as image',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              value: _copyPageAsImageEnabled,
              onChanged: (v) async {
                setState(() => _copyPageAsImageEnabled = v);
                await _settings.setCopyPageAsImageEnabled(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbout() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          const Spacer(),
          Text(
            'AskoPDF',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'app-1.0.0 · gelide-0.6-l · pdfium-152.0.7961',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () async {
                final uri = Uri.parse('https://github.com/askoq');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              child: Text(
                'askoq',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
