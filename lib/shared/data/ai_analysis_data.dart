class AiAnalysisStateData {
  const AiAnalysisStateData({
    required this.source,
    required this.tradeDate,
    required this.enabled,
    required this.reason,
    required this.provider,
    required this.model,
    required this.generatedAt,
    required this.analysis,
    required this.cached,
    this.success,
  });

  final String source;
  final String? tradeDate;
  final bool enabled;
  final String reason;
  final String provider;
  final String model;
  final String? generatedAt;
  final String analysis;
  final bool cached;
  final bool? success;

  bool get hasAnalysis => analysis.trim().isNotEmpty;

  factory AiAnalysisStateData.empty({
    String source = '',
    String reason = '',
  }) {
    return AiAnalysisStateData(
      source: source,
      tradeDate: null,
      enabled: false,
      reason: reason,
      provider: 'kimi',
      model: '',
      generatedAt: null,
      analysis: '',
      cached: false,
      success: null,
    );
  }

  factory AiAnalysisStateData.fromJson(Map<String, dynamic> json) {
    return AiAnalysisStateData(
      source: json['source']?.toString() ?? '',
      tradeDate: json['trade_date']?.toString(),
      enabled: json['enabled'] as bool? ?? false,
      reason: json['reason']?.toString() ?? '',
      provider: json['provider']?.toString() ?? 'kimi',
      model: json['model']?.toString() ?? '',
      generatedAt: json['generated_at']?.toString(),
      analysis: json['analysis']?.toString() ?? '',
      cached: json['cached'] as bool? ?? false,
      success: json['success'] as bool?,
    );
  }
}
