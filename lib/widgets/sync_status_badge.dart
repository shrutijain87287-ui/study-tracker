import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/cloud_sync_service.dart';
import '../theme/app_theme.dart';

class SyncStatusBadge extends StatelessWidget {
  final bool showLabel;
  final VoidCallback? onTap;

  const SyncStatusBadge({
    super.key,
    this.showLabel = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: CloudSyncService.syncStatusNotifier,
      builder: (context, status, _) {
        return ValueListenableBuilder<DateTime?>(
          valueListenable: CloudSyncService.lastSyncNotifier,
          builder: (context, lastSync, _) {
            Color bg;
            Color fg;
            IconData icon;
            String text;

            switch (status) {
              case SyncStatus.syncing:
                bg = AppColors.pastelPurple;
                fg = AppColors.primary;
                icon = Icons.sync_rounded;
                text = 'Syncing...';
                break;
              case SyncStatus.synced:
                bg = AppColors.pastelMint;
                fg = AppColors.pastelMintText;
                icon = Icons.cloud_done_rounded;
                text = lastSync != null
                    ? 'Synced ${DateFormat('h:mm a').format(lastSync)}'
                    : 'Synced';
                break;
              case SyncStatus.offline:
                bg = const Color(0xFFE2E8F0);
                fg = const Color(0xFF64748B);
                icon = Icons.cloud_off_rounded;
                text = 'Offline';
                break;
              case SyncStatus.failed:
                bg = AppColors.pastelOrange;
                fg = AppColors.pastelOrangeText;
                icon = Icons.cloud_sync_outlined;
                text = 'Sync Failed';
                break;
              case SyncStatus.idle:
                if (lastSync != null) {
                  bg = AppColors.pastelMint;
                  fg = AppColors.pastelMintText;
                  icon = Icons.cloud_done_rounded;
                  text = 'Synced ${DateFormat('h:mm a').format(lastSync)}';
                } else {
                  bg = const Color(0xFFE2E8F0);
                  fg = const Color(0xFF64748B);
                  icon = Icons.cloud_queue_rounded;
                  text = 'Not Synced';
                }
                break;
            }

            final pill = Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == SyncStatus.syncing)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(fg),
                      ),
                    )
                  else
                    Icon(icon, size: 14, color: fg),
                  if (showLabel) ...[
                    const SizedBox(width: 6),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ],
                ],
              ),
            );

            if (onTap != null) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTap,
                  child: pill,
                ),
              );
            }

            return pill;
          },
        );
      },
    );
  }
}
