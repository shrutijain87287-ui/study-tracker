import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/class_model.dart';
import '../theme/app_theme.dart';

/// Interactive modal allowing students to disambiguate and select the exact
/// channel for a teacher, ensuring strict channel-filtered video searches.
class ChannelSelectionDialog extends StatelessWidget {
  final String teacherName;
  final String? subjectName;
  final List<ChannelCandidate> candidates;
  final void Function(ChannelCandidate selectedChannel) onChannelSelected;
  final VoidCallback onSearchAllChannels;

  const ChannelSelectionDialog({
    super.key,
    required this.teacherName,
    this.subjectName,
    required this.candidates,
    required this.onChannelSelected,
    required this.onSearchAllChannels,
  });

  static Future<void> show({
    required BuildContext context,
    required String teacherName,
    String? subjectName,
    required List<ChannelCandidate> candidates,
    required void Function(ChannelCandidate selectedChannel) onChannelSelected,
    required VoidCallback onSearchAllChannels,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ChannelSelectionDialog(
        teacherName: teacherName,
        subjectName: subjectName,
        candidates: candidates,
        onChannelSelected: onChannelSelected,
        onSearchAllChannels: onSearchAllChannels,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E1B2E) : Colors.white;
    final cardBg = isDark ? const Color(0xFF28243D) : const Color(0xFFF9F8FD);
    final borderColor =
        isDark ? const Color(0xFF38325A) : const Color(0xFFE9E5F5);
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Padding(
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
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person_search_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Channel for "$teacherName"',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subjectName != null && subjectName!.isNotEmpty
                              ? 'Strict filter: searching only for "$subjectName"'
                              : 'Select the official educator channel to lock results',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: textSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Informational badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2E284D)
                      : const Color(0xFFF3EFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF453D6B)
                        : const Color(0xFFDDD4F7),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Multiple channels found. Choosing a channel guarantees zero videos from unrelated teachers.',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Candidates List
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final candidate = candidates[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).pop();
                        onChannelSelected(candidate);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Channel Avatar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: 48,
                                height: 48,
                                color: AppColors.primary.withValues(alpha: 0.1),
                                child: candidate.thumbnailUrl.isNotEmpty
                                    ? Image.network(
                                        candidate.thumbnailUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                            candidate.title.isNotEmpty
                                                ? candidate.title[0]
                                                    .toUpperCase()
                                                : 'C',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          candidate.title.isNotEmpty
                                              ? candidate.title[0].toUpperCase()
                                              : 'C',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Channel Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          candidate.title,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (candidate.isVerified) ...[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (candidate.subscriberCount != null &&
                                      candidate
                                          .subscriberCount!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      candidate.subscriberCount!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                  if (candidate.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      candidate.description,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Select Button
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Select',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onSearchAllChannels();
                    },
                    icon: Icon(Icons.public_rounded,
                        size: 16, color: textSecondary),
                    label: Text(
                      'Search all channels without filter',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
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
