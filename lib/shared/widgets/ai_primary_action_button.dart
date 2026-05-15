import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Use for every action that requests or regenerates an AI conclusion.
class AiPrimaryActionButton extends StatelessWidget {
  const AiPrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
    this.tooltip,
    this.icon = Icons.auto_awesome_rounded,
    this.minWidth = 176,
    this.height = 52,
    this.remainingUses,
    this.totalLimit,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? loadingLabel;
  final String? tooltip;
  final IconData icon;
  final double minWidth;
  final double height;
  final int? remainingUses;
  final int? totalLimit;

  @override
  Widget build(BuildContext context) {
    final exhausted = remainingUses != null && remainingUses! <= 0;
    final effectiveOnPressed = exhausted ? null : onPressed;
    final enabled = effectiveOnPressed != null;
    final active = enabled || loading;
    final foreground = active ? Colors.white : AppTheme.mutedText;
    final borderColor =
        active ? const Color(0xFFFFB547) : AppTheme.outlineStrong;
    final background =
        active ? const Color(0xFF155EEF) : AppTheme.surfaceStrong;
    final child = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: active
            ? <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF155EEF).withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: FilledButton.icon(
        onPressed: loading ? () {} : effectiveOnPressed,
        style: FilledButton.styleFrom(
          minimumSize: Size(minWidth, height),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: AppTheme.surfaceStrong,
          disabledForegroundColor: AppTheme.mutedText,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: borderColor, width: active ? 1.4 : 1),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        icon: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.16)
                : AppTheme.neutralSoft,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: active
                  ? Colors.white.withValues(alpha: 0.26)
                  : AppTheme.outline,
            ),
          ),
          child: loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(foreground),
                  ),
                )
              : Icon(icon, size: 18, color: foreground),
        ),
        label: Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loading ? (loadingLabel ?? label) : label),
              if (remainingUses != null && totalLimit != null && totalLimit! > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: exhausted
                        ? Colors.red.withValues(alpha: 0.7)
                        : const Color(0xFFFFB547),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$remainingUses/$totalLimit',
                    style: TextStyle(
                      color: exhausted ? Colors.white : const Color(0xFF17212B),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              ] else if (active) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB547),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'AI',
                    style: TextStyle(
                      color: Color(0xFF17212B),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final wrapped = Semantics(
      button: true,
      label: 'AI ${loading ? (loadingLabel ?? label) : label}',
      child: child,
    );

    final effectiveTooltip = exhausted
        ? '超过当日免费使用限制'
        : tooltip;
    if (effectiveTooltip == null || effectiveTooltip.isEmpty) {
      return wrapped;
    }
    return Tooltip(message: effectiveTooltip, child: wrapped);
  }
}

class AiSecondaryActionButton extends StatelessWidget {
  const AiSecondaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.article_outlined,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(132, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        foregroundColor: AppTheme.text,
        backgroundColor: AppTheme.primarySoft.withValues(alpha: 0.64),
        disabledBackgroundColor: AppTheme.surfaceSoft,
        side: BorderSide(
          color: onPressed == null
              ? AppTheme.outline
              : AppTheme.primary.withValues(alpha: 0.34),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );

    if (tooltip == null || tooltip!.isEmpty) {
      return child;
    }
    return Tooltip(message: tooltip!, child: child);
  }
}

class AiActionGroup extends StatelessWidget {
  const AiActionGroup({
    super.key,
    required this.primary,
    required this.children,
  });

  final Widget primary;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: primary,
        ),
        ...children,
      ],
    );
  }
}
