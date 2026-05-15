import 'package:flutter/material.dart';

class TradeDateActionBar extends StatelessWidget {
  const TradeDateActionBar({
    super.key,
    required this.resolvedTradeDate,
    required this.selectedTradeDate,
    required this.previousTradeDate,
    required this.nextTradeDate,
    required this.onSelectTradeDate,
    this.leadingChildren = const <Widget>[],
    this.trailingChildren = const <Widget>[],
    this.keyPrefix,
    this.spacing = 8,
    this.runSpacing = 8,
    this.buttonStyle,
    this.previousLabel = '上一日',
    this.nextLabel = '下一日',
    this.latestLabel = '最新',
  });

  final String? resolvedTradeDate;
  final String? selectedTradeDate;
  final String? previousTradeDate;
  final String? nextTradeDate;
  final ValueChanged<String?> onSelectTradeDate;
  final List<Widget> leadingChildren;
  final List<Widget> trailingChildren;
  final String? keyPrefix;
  final double spacing;
  final double runSpacing;
  final ButtonStyle? buttonStyle;
  final String previousLabel;
  final String nextLabel;
  final String latestLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        ...leadingChildren,
        FilledButton.tonalIcon(
          key: _buildKey('prev-trade-date'),
          onPressed: previousTradeDate == null
              ? null
              : () => onSelectTradeDate(previousTradeDate),
          style: buttonStyle,
          icon: const Icon(Icons.chevron_left_rounded),
          label: Text(previousLabel),
        ),
        FilledButton.tonalIcon(
          key: _buildKey('next-trade-date'),
          onPressed: nextTradeDate == null
              ? null
              : () => onSelectTradeDate(nextTradeDate),
          style: buttonStyle,
          icon: const Icon(Icons.chevron_right_rounded),
          label: Text(nextLabel),
        ),
        if (resolvedTradeDate != null)
          ActionChip(
            key: _buildKey('trade-date-latest'),
            label: Text(latestLabel),
            onPressed: selectedTradeDate == null
                ? null
                : () => onSelectTradeDate(null),
          ),
        ...trailingChildren,
      ],
    );
  }

  ValueKey<String>? _buildKey(String suffix) {
    if (keyPrefix == null || keyPrefix!.isEmpty) {
      return null;
    }
    return ValueKey<String>('$keyPrefix-$suffix');
  }
}

class TradeDateChoiceChips extends StatelessWidget {
  const TradeDateChoiceChips({
    super.key,
    required this.availableTradeDates,
    required this.resolvedTradeDate,
    required this.onSelectTradeDate,
    this.keyPrefix,
    this.maxVisibleDates = 8,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  final List<String> availableTradeDates;
  final String? resolvedTradeDate;
  final ValueChanged<String> onSelectTradeDate;
  final String? keyPrefix;
  final int maxVisibleDates;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    if (availableTradeDates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: availableTradeDates.take(maxVisibleDates).map((tradeDate) {
        return ChoiceChip(
          key: _buildKey(tradeDate),
          label: Text(tradeDate),
          selected: resolvedTradeDate == tradeDate,
          onSelected: (_) => onSelectTradeDate(tradeDate),
        );
      }).toList(growable: false),
    );
  }

  ValueKey<String>? _buildKey(String tradeDate) {
    if (keyPrefix == null || keyPrefix!.isEmpty) {
      return null;
    }
    return ValueKey<String>('$keyPrefix-trade-date-$tradeDate');
  }
}
