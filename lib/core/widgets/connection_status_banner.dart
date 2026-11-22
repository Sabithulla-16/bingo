import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_typography.dart';
import '../services/network_connectivity_manager.dart';

/// Compact connection status banner adhering strictly to BINGO design tokens.
/// Only renders when the connection is degraded or disconnected.
class ConnectionStatusBanner extends ConsumerWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(networkStatusProvider);

    // Mute routine background checking and online states
    if (status == NetworkStatus.online || status == NetworkStatus.checking) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case NetworkStatus.offline:
        bgColor = const Color(0xFFFFECEB);
        borderColor = AppColors.primaryCoral.withAlpha(100);
        textColor = const Color(0xFFC0392B);
        icon = Icons.wifi_off_rounded;
        break;
      case NetworkStatus.backendUnavailable:
        bgColor = const Color(0xFFFFF3CD);
        borderColor = const Color(0xFFFFEEBA);
        textColor = const Color(0xFF856404);
        icon = Icons.cloud_off_rounded;
        break;
      case NetworkStatus.reconnecting:
      case NetworkStatus.realtimeDisconnected:
        bgColor = AppColors.lightLavender;
        borderColor = AppColors.primaryNavy.withAlpha(50);
        textColor = AppColors.primaryNavy;
        icon = Icons.sync_rounded;
        break;
      case NetworkStatus.checking:
        bgColor = AppColors.surfaceContainerLow;
        borderColor = AppColors.structuralBorder;
        textColor = AppColors.textMuted;
        icon = Icons.wifi_find_rounded;
        break;
      case NetworkStatus.online:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadii.roundedMd,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status.displayTitle,
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                Text(
                  status.displaySubtitle,
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 10.5,
                    color: textColor.withAlpha(200),
                  ),
                ),
              ],
            ),
          ),
          if (status == NetworkStatus.offline ||
              status == NetworkStatus.backendUnavailable)
            InkWell(
              onTap: () {
                ref.read(networkStatusProvider.notifier).checkConnection();
              },
              borderRadius: AppRadii.roundedFull,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  'RETRY',
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
