import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/review_summary.dart';
import 'package:kisekae/services/review_assistant.dart';

const _primary = Color(0xFF8B2E3E);
const _surface = Color(0xFFFBF8F5);
const _line = Color(0xFFD3C7B8);
const _pageBg = Color(0xFFEFE8DF);
const _muted = Color(0xFFE5DDD2);

class ReviewChatBar extends StatefulWidget {
  final int productId;
  final bool inline;

  const ReviewChatBar({
    super.key,
    required this.productId,
    this.inline = false,
  });

  @override
  State<ReviewChatBar> createState() => _ReviewChatBarState();
}

class _ReviewChatBarState extends State<ReviewChatBar> {
  late final _ChatController _controller = _ChatController(widget.productId);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openChat() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _pageBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ChatSheet(controller: _controller),
    );
  }

  Widget _pill() {
    return GestureDetector(
      onTap: _openChat,
      child: Container(
        height: 48,
        padding: const EdgeInsets.only(left: 14, right: 8),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 20, color: _primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Ask about this product's reviews",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _primary,
              ),
              child: const Icon(
                Icons.arrow_upward,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.inline) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _pill(),
      );
    }

    return Container(
      color: _pageBg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SafeArea(top: false, child: _pill()),
    );
  }
}

class _ChatEntry {
  final bool isUser;
  final String text;
  final bool isRefusal;

  _ChatEntry({
    required this.isUser,
    required this.text,
    this.isRefusal = false,
  });
}

class _ChatController extends ChangeNotifier {
  final int productId;
  final _assistant = ReviewAssistant();

  _ChatController(this.productId);

  final List<_ChatEntry> entries = [];
  bool sending = false;
  String? failedQuestion;
  String? errorMessage;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> ask(String question) async {
    final text = question.trim();
    if (text.isEmpty || sending) return;

    final history = entries
        .map(
          (entry) => ReviewChatMessage(
            role: entry.isUser ? 'user' : 'assistant',
            content: entry.text,
          ),
        )
        .toList();

    failedQuestion = null;
    errorMessage = null;
    entries.add(_ChatEntry(isUser: true, text: text));
    sending = true;
    _notify();

    try {
      final reply = await _assistant.askQuestion(
        productId,
        text,
        history: history,
      );
      entries.add(
        _ChatEntry(
          isUser: false,
          text: reply.reply.trim().isEmpty
              ? 'I could not find an answer in the reviews.'
              : reply.reply.trim(),
          isRefusal: reply.isGuardrailRefusal,
        ),
      );
    } on ApiException catch (e) {
      failedQuestion = text;
      errorMessage = e.message;
    } catch (_) {
      failedQuestion = text;
      errorMessage = 'Could not get an answer. Please try again.';
    } finally {
      sending = false;
      _notify();
    }
  }

  Future<void> retry() async {
    final question = failedQuestion;
    if (question == null || sending) return;
    if (entries.isNotEmpty && entries.last.isUser) entries.removeLast();
    await ask(question);
  }
}

class _ChatSheet extends StatefulWidget {
  final _ChatController controller;

  const _ChatSheet({required this.controller});

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  static const _suggestions = [
    'How does it fit?',
    'Is the quality good?',
    'Any common complaints?',
  ];

  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _send([String? text]) {
    final question = (text ?? _input.text).trim();
    if (question.isEmpty || widget.controller.sending) return;
    _input.clear();
    widget.controller.ask(question);
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 20, color: _primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask about reviews',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Answers are based on customer reviews only',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 40,
              color: _primary.withOpacity(0.7),
            ),
            const SizedBox(height: 12),
            const Text(
              "Ask anything about this product's reviews",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final suggestion in _suggestions)
                  ActionChip(
                    label: Text(suggestion),
                    onPressed: () => _send(suggestion),
                    backgroundColor: _surface,
                    side: const BorderSide(color: _line),
                    labelStyle: const TextStyle(fontSize: 13, color: _primary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _messages() {
    final controller = widget.controller;
    final extra = controller.sending ? 1 : 0;

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: controller.entries.length + extra,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= controller.entries.length) return const _TypingBubble();
        return _Bubble(entry: controller.entries[index]);
      },
    );
  }

  Widget _errorRow() {
    final controller = widget.controller;
    if (controller.failedQuestion == null || controller.sending) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE3E3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              controller.errorMessage ?? 'Could not get an answer.',
              style: const TextStyle(fontSize: 12, color: Color(0xFFC62828)),
            ),
          ),
          TextButton(
            onPressed: controller.retry,
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _inputRow() {
    final sending = widget.controller.sending;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              maxLength: 500,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Ask about fit, quality, comfort…',
                counterText: '',
                filled: true,
                fillColor: _surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: _line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: _line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            height: 46,
            child: FilledButton(
              onPressed: sending ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                disabledBackgroundColor: _primary.withOpacity(0.4),
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            _header(),
            const Divider(height: 1, color: _line),
            Expanded(
              child: controller.entries.isEmpty && !controller.sending
                  ? _emptyState()
                  : _messages(),
            ),
            _errorRow(),
            _inputRow(),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _ChatEntry entry;

  const _Bubble({required this.entry});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.8;

    if (entry.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            entry.text,
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: entry.isRefusal ? _muted : _surface,
          border: Border.all(color: _line),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.isRefusal) ...[
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                entry.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: entry.isRefusal ? Colors.black54 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
            ),
            SizedBox(width: 10),
            Text(
              'Reading the reviews…',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
