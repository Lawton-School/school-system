import 'package:flutter/material.dart';
import '../core/theme.dart';

enum StitchChipVariant { primary, success, warn, danger, info, neutral }

/// Reusable Stitch status chip / pill badge
class StitchChip extends StatelessWidget {
  final String label;
  final StitchChipVariant variant;
  final IconData? icon;

  const StitchChip({
    super.key,
    required this.label,
    this.variant = StitchChipVariant.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (variant) {
      case StitchChipVariant.success:
        bg = AppTheme.stitchSuccessSoft;
        fg = AppTheme.stitchSuccessText;
        break;
      case StitchChipVariant.warn:
        bg = AppTheme.stitchWarnSoft;
        fg = AppTheme.stitchWarnText;
        break;
      case StitchChipVariant.danger:
        bg = AppTheme.stitchDangerSoft;
        fg = AppTheme.stitchDangerText;
        break;
      case StitchChipVariant.info:
        bg = AppTheme.stitchInfoSoft;
        fg = AppTheme.stitchInfoText;
        break;
      case StitchChipVariant.neutral:
        bg = const Color(0xFFF1F3F7);
        fg = const Color(0xFF5D677A);
        break;
      case StitchChipVariant.primary:
        bg = AppTheme.primarySoft;
        fg = AppTheme.primaryDark;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard Stitch card with 14px radius, 1px border, and soft elevation shadow
class StitchCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const StitchCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.stitchBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A172033),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: cardContent,
      );
    }
    return cardContent;
  }
}

/// KPI Metric Card with bold typography and status coloration
class StitchKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final StitchChipVariant? statusColor;
  final IconData? icon;

  const StitchKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    this.statusColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color valueColor = AppTheme.stitchHeading;
    if (statusColor == StitchChipVariant.success) {
      valueColor = AppTheme.stitchSuccessText;
    } else if (statusColor == StitchChipVariant.warn) {
      valueColor = AppTheme.stitchWarnText;
    } else if (statusColor == StitchChipVariant.danger) {
      valueColor = AppTheme.stitchDangerText;
    } else if (statusColor == StitchChipVariant.info) {
      valueColor = AppTheme.stitchInfoText;
    }

    return StitchCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppTheme.stitchMuted,
                ),
              ),
              if (icon != null)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: AppTheme.primary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: valueColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppTheme.stitchMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Offline-first synchronized status alert banner
class StitchSyncBanner extends StatelessWidget {
  final bool isOnline;
  final int pendingMutations;

  const StitchSyncBanner({
    super.key,
    this.isOnline = true,
    this.pendingMutations = 0,
  });

  @override
  Widget build(BuildContext context) {
    final synced = isOnline && pendingMutations == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: synced ? const Color(0xFFF5F3FF) : const Color(0xFFFFFBEB),
        border: Border.all(
          color: synced ? const Color(0xFFD7D1FF) : const Color(0xFFFDE68A),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            synced ? Icons.cloud_done_rounded : Icons.cloud_sync_rounded,
            color: synced ? AppTheme.primaryDark : AppTheme.stitchWarnText,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              synced
                  ? 'Everything is synced. Attendance and grade changes continue offline and sync automatically.'
                  : 'Working offline. $pendingMutations changes queued locally in Drift database.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: synced ? const Color(0xFF4A3C98) : const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header with optional link or action
class StitchSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const StitchSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.stitchHeading,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.stitchMuted,
                ),
              ),
            ],
          ],
        ),
        ?trailing,
      ],
    );
  }
}
