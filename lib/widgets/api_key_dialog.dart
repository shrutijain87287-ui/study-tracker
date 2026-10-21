import 'package:flutter/material.dart';
import '../services/youtube_service.dart';
import '../theme/app_theme.dart';

class ApiKeyDialog extends StatefulWidget {
  const ApiKeyDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ApiKeyDialog(),
    );
  }

  @override
  State<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<ApiKeyDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;
  bool _isTesting = false;
  String _currentKey = '';
  String? _statusMessage;
  bool _isSuccess = false;
  bool _showHelp = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await YouTubeService.getApiKey();
    setState(() {
      _currentKey = key;
      _controller.text = key;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      // Clear key to switch back to Demo Mode
      await YouTubeService.setApiKey('');
      if (!mounted) return;
      setState(() {
        _currentKey = '';
        _isSuccess = true;
        _statusMessage = 'Switched to honest Demo Mode with curated classes.';
      });
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.of(context).pop(true);
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _statusMessage = null;
    });

    final testResult = await YouTubeService.testApiKey(key);

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _isSuccess = testResult.isValid;
      _statusMessage = testResult.message;
      if (testResult.isValid) {
        _currentKey = key;
      }
    });

    if (testResult.isValid) {
      await YouTubeService.setApiKey(key);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    }
  }

  Future<void> _switchToDemoMode() async {
    await YouTubeService.setApiKey('');
    if (!mounted) return;
    setState(() {
      _controller.clear();
      _currentKey = '';
      _isSuccess = true;
      _statusMessage = 'Active: Demo Mode (Curated Multi-Teacher Catalog)';
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.smart_display_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'YouTube API & Demo Settings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'Search live YouTube or explore curated demo mode',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          color: textSecondary,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Current Mode Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _currentKey.isEmpty
                            ? AppColors.pastelMint
                            : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _currentKey.isEmpty
                              ? AppColors.pastelMintText.withValues(alpha: 0.3)
                              : AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _currentKey.isEmpty
                                ? Icons.verified_rounded
                                : Icons.cloud_done_rounded,
                            color: _currentKey.isEmpty
                                ? AppColors.pastelMintText
                                : AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentKey.isEmpty
                                      ? 'Active: Curated Demo Mode'
                                      : 'Active: Live YouTube Data API v3',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: _currentKey.isEmpty
                                        ? AppColors.pastelMintText
                                        : AppColors.primary,
                                  ),
                                ),
                                Text(
                                  _currentKey.isEmpty
                                      ? 'Provides multi-teacher educational results with zero setup or API limits.'
                                      : 'Searching live YouTube with your personal API key.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Input Field
                    Text(
                      'Google Cloud YouTube Data API v3 Key',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'AIzaSy...',
                        hintStyle: TextStyle(
                            color: textSecondary.withValues(alpha: 0.6),
                            fontSize: 13),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: textPrimary,
                        fontFamily: 'monospace',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),

                    // Help guide toggle
                    GestureDetector(
                      onTap: () => setState(() => _showHelp = !_showHelp),
                      child: Row(
                        children: [
                          Icon(
                            _showHelp
                                ? Icons.arrow_drop_up_rounded
                                : Icons.arrow_drop_down_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          Text(
                            _showHelp
                                ? 'Hide instructions'
                                : 'How to get a free YouTube API key?',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_showHelp) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceDark
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          '1. Visit console.cloud.google.com\n'
                          '2. Create a project & enable "YouTube Data API v3"\n'
                          '3. Create Credentials -> API key (10,000 free queries/day)\n'
                          '4. Paste key above & click "Test & Save"',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ],

                    // Status Message
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isSuccess
                              ? AppColors.pastelMint
                              : AppColors.pastelPink,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isSuccess
                                  ? Icons.check_circle_rounded
                                  : Icons.error_outline_rounded,
                              size: 18,
                              color: _isSuccess
                                  ? AppColors.pastelMintText
                                  : AppColors.pastelPinkText,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusMessage!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _isSuccess
                                      ? AppColors.pastelMintText
                                      : AppColors.pastelPinkText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),

                    // Actions
                    Row(
                      children: [
                        if (_currentKey.isNotEmpty)
                          TextButton.icon(
                            onPressed: _isTesting ? null : _switchToDemoMode,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Use Demo Mode'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondaryLight,
                            ),
                          ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _isTesting ? null : _testAndSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                          ),
                          child: _isTesting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
