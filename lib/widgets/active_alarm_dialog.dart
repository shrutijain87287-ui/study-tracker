import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/alarm_service.dart';
import '../theme/app_theme.dart';

class ActiveAlarmDialog extends StatefulWidget {
  final ActiveAlarmState alarmState;
  final VoidCallback onDismiss;

  const ActiveAlarmDialog({
    super.key,
    required this.alarmState,
    required this.onDismiss,
  });

  static Future<void> show(BuildContext context, ActiveAlarmState state) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ActiveAlarmDialog(
        alarmState: state,
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  State<ActiveAlarmDialog> createState() => _ActiveAlarmDialogState();
}

class _ActiveAlarmDialogState extends State<ActiveAlarmDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reminder = widget.alarmState.reminder;
    final snoozeMinutes = widget.alarmState.snoozeMinutes;
    final timeStr =
        '${reminder.hour.toString().padLeft(2, '0')}:${reminder.minute.toString().padLeft(2, '0')}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          AlarmService.stopAlarm();
          widget.onDismiss();
        }
      },
      child: AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing Alarm Icon Container
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnim.value,
                  child: child,
                );
              },
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.alarm_on_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Heading & Subtitle
            Text(
              'Study Reminder! ⏰',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : const Color(0xFF15123A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              reminder.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            if (reminder.subjectName != null &&
                reminder.subjectName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF28234B)
                      : const Color(0xFFF1ECFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '📚 ${reminder.subjectName!}',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Scheduled Time Display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1B1930) : const Color(0xFFFAF9FE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isDark ? AppColors.borderDark : const Color(0xFFECE7F6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 16, color: Color(0xFF8882A3)),
                  const SizedBox(width: 8),
                  Text(
                    timeStr,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : const Color(0xFF15123A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons (Snooze + Stop)
            Row(
              children: [
                // Snooze Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      AlarmService.snoozeAlarm(snoozeMinutes);
                      widget.onDismiss();
                    },
                    icon: const Icon(Icons.snooze_rounded, size: 18),
                    label: Text(
                      'Snooze (${snoozeMinutes}m)',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF3B3663)
                            : const Color(0xFFD6CEEE),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Stop Alarm Button
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        AlarmService.stopAlarm();
                        widget.onDismiss();
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Stop Alarm',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
