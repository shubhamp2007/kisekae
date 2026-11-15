import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/review_summary.dart';
import 'package:kisekae/services/review_assistant.dart';

class ReviewSummarySection extends StatefulWidget {
  final int productId;

  const ReviewSummarySection({super.key, required this.productId});

  @override
  State<ReviewSummarySection> createState() => _ReviewSummarySectionState();
}

class _ReviewSummarySectionState extends State<ReviewSummarySection> {
  final _assistant = ReviewAssistant();

  ReviewSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReviewSummarySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      setState(() {
        _summary = null;
        _loading = true;
      });
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final summary = await _assistant.getSummary(widget.productId);
      if (!mounted) return;
      setState(() {
        _summary = (summary != null && summary.hasContent) ? summary : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _summary = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }

    final summary = _summary;
    if (summary == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _SummaryCard(summary: summary),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ReviewSummary summary;

  const _SummaryCard({required this.summary});

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _footer() {
    final parts = <String>[];
    if (summary.reviewCountAtSummary > 0) {
      final count = summary.reviewCountAtSummary;
      parts.add('Based on $count ${count == 1 ? 'review' : 'reviews'}');
    }
    final generated = summary.generatedAt?.toLocal();
    if (generated != null) {
      parts.add(
        'Updated ${generated.day} ${_months[generated.month - 1]} ${generated.year}',
      );
    }
    return parts.join('  •  ');
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final c = context.appColors;
    final pros = summary.prosList;
    final cons = summary.consList;
    final footer = _footer();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'AI Review Summary',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary.summaryText.trim(),
            style: TextStyle(fontSize: 14, height: 1.4, color: cs.onSurface),
          ),
          if (summary.sizingVerdict.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.straighten, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Sizing: ${summary.sizingVerdict.trim()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (pros.isNotEmpty) ...[
            const SizedBox(height: 14),
            _PointList(
              title: 'What customers like',
              points: pros,
              icon: Icons.check_circle_outline,
              color: c.success,
            ),
          ],
          if (cons.isNotEmpty) ...[
            const SizedBox(height: 14),
            _PointList(
              title: 'What to consider',
              points: cons,
              icon: Icons.error_outline,
              color: cs.error,
            ),
          ],
          if (summary.sentimentDistribution.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _SentimentBar(text: summary.sentimentDistribution),
          ],
          if (footer.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(footer, style: TextStyle(fontSize: 11, color: c.mutedText)),
          ],
        ],
      ),
    );
  }
}

class _PointList extends StatelessWidget {
  final String title;
  final List<String> points;
  final IconData icon;
  final Color color;

  const _PointList({
    required this.title,
    required this.points,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = context.cs.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 6),
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    point,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SentimentBar extends StatelessWidget {
  final String text;

  const _SentimentBar({required this.text});

  static final _pattern = RegExp(
    r'(positive|neutral|negative)\D{0,12}?(\d+(?:\.\d+)?)',
    caseSensitive: false,
  );

  Map<String, double> _parse() {
    final values = <String, double>{};
    for (final match in _pattern.allMatches(text)) {
      final key = match.group(1)!.toLowerCase();
      final value = double.tryParse(match.group(2)!) ?? 0;
      values.putIfAbsent(key, () => value);
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final c = context.appColors;
    final values = _parse();
    final total = values.values.fold<double>(0, (sum, v) => sum + v);

    if (values.isEmpty || total <= 0) {
      return Text(
        'Sentiment: ${text.trim()}',
        style: TextStyle(fontSize: 12, color: cs.onSurface),
      );
    }

    const order = ['positive', 'neutral', 'negative'];
    final colors = {
      'positive': c.success,
      'neutral': c.mutedText,
      'negative': cs.error,
    };

    final shown = order.where((key) => (values[key] ?? 0) > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer sentiment',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              for (final key in shown)
                Expanded(
                  flex: ((values[key]! / total) * 1000).round().clamp(1, 1000),
                  child: Container(height: 8, color: colors[key]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final key in shown)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors[key],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${key[0].toUpperCase()}${key.substring(1)} ${((values[key]! / total) * 100).round()}%',
                    style: TextStyle(fontSize: 11, color: cs.onSurface),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
