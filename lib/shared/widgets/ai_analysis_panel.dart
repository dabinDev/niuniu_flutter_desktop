import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../data/ai_analysis_data.dart';

class AiAnalysisPanel extends StatelessWidget {
  const AiAnalysisPanel({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.state,
  });

  final String title;
  final String actionLabel;
  final AiAnalysisStateData state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAnalysis = state.hasAnalysis;
    final accent = state.enabled ? AppTheme.primary : AppTheme.mutedText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasAnalysis
            ? AppTheme.primarySoft.withValues(alpha: 0.52)
            : AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasAnalysis
              ? AppTheme.primary.withValues(alpha: 0.18)
              : AppTheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                state.generatedAt == null
                    ? state.model
                    : _formatTimestamp(state.generatedAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasAnalysis
                ? state.analysis
                : (state.reason.isEmpty ? actionLabel : state.reason),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: hasAnalysis ? AppTheme.text : AppTheme.mutedText,
              height: 1.45,
            ),
          ),
          if (!hasAnalysis && state.reason != actionLabel) ...[
            const SizedBox(height: 4),
            Text(
              actionLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.mutedText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatTimestamp(String? value) {
  if (value == null || value.isEmpty) {
    return '--';
  }
  return value.replaceFirst('T', ' ').split('.').first;
}
