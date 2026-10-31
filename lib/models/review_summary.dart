class ReviewSummary {
  final int productId;
  final String summaryText;
  final String pros;
  final String cons;
  final String sizingVerdict;
  final String sentimentDistribution;
  final int reviewCountAtSummary;
  final DateTime? generatedAt;

  ReviewSummary({
    required this.productId,
    required this.summaryText,
    required this.pros,
    required this.cons,
    required this.sizingVerdict,
    required this.sentimentDistribution,
    required this.reviewCountAtSummary,
    this.generatedAt,
  });

  static List<String> _splitPoints(String text) {
    return text
        .split(RegExp(r'\n|•'))
        .map(
          (line) =>
              line.replaceFirst(RegExp(r'^\s*(?:[-*]|\d+[.)])\s*'), '').trim(),
        )
        .where((line) => line.isNotEmpty)
        .toList();
  }

  List<String> get prosList => _splitPoints(pros);

  List<String> get consList => _splitPoints(cons);

  bool get hasContent => summaryText.trim().isNotEmpty;

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    return ReviewSummary(
      productId: json['product_id'] as int? ?? 0,
      summaryText: json['summary_text']?.toString() ?? '',
      pros: json['pros']?.toString() ?? '',
      cons: json['cons']?.toString() ?? '',
      sizingVerdict: json['sizing_verdict']?.toString() ?? '',
      sentimentDistribution: json['sentiment_distribution']?.toString() ?? '',
      reviewCountAtSummary: json['review_count_at_summary'] as int? ?? 0,
      generatedAt: DateTime.tryParse(json['generated_at']?.toString() ?? ''),
    );
  }
}

class ReviewChatMessage {
  final String role;
  final String content;

  const ReviewChatMessage({required this.role, required this.content});

  const ReviewChatMessage.user(this.content) : role = 'user';

  const ReviewChatMessage.assistant(this.content) : role = 'assistant';

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class ReviewChatReply {
  final String reply;
  final bool isGuardrailRefusal;

  ReviewChatReply({required this.reply, required this.isGuardrailRefusal});

  factory ReviewChatReply.fromJson(Map<String, dynamic> json) {
    return ReviewChatReply(
      reply: json['reply']?.toString() ?? '',
      isGuardrailRefusal: json['is_guardrail_refusal'] as bool? ?? false,
    );
  }
}
