import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../services/api_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class AskExpensesScreen extends StatefulWidget {
  const AskExpensesScreen({super.key});

  @override
  State<AskExpensesScreen> createState() => _AskExpensesScreenState();
}

class _AskExpensesScreenState extends State<AskExpensesScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isTyping = false;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Ask questions about your transactions, categories, recurring commitments, or balances.',
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  final List<String> _suggestions = [
    'How much did I spend on food last month?',
    'What are my recurring expenses?',
    'Who owes me money?',
    'Where did most of my money go this year?',
    'How much did I spend at Swiggy?',
    'What is my total spending this month?',
  ];

  @override
  void initState() {
    super.initState();
    ApiService.getCurrentUser()
        .then((user) {
          if (mounted) {
            setState(() {
              _messages[0] = ChatMessage(
                text:
                    'Query ledger records for transactions, categories, recurring commitments, or balances.',
                isUser: false,
                timestamp: DateTime.now(),
              );
            });
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String query) async {
    final text = query.trim();
    if (text.isEmpty) return;

    _textCtrl.clear();
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final response = await ApiService.naturalLanguageQuery(text);
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessage(
            text: response.answer,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessage(
            text: 'Unable to reach the server. Please verify your connection.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.search,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ask Expenses',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Ledger queries',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ─── Quick Query Chips ──────────────────────────────────
          Container(
            height: 36,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              itemBuilder: (context, i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _sendMessage(_suggestions[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusSmall,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: Text(
                          _suggestions[i],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ─── Messages List ──────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                return _ChatBubble(message: msg);
              },
            ),
          ),

          // ─── Typing Indicator ───────────────────────────────────
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Querying ledger records...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ─── Input Bar ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surfaceCard,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ask about your transactions...',
                      hintStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 13,
                          ),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusSmall,
                        ),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusSmall,
                        ),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusSmall,
                        ),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      LucideIcons.arrowUp,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () => _sendMessage(_textCtrl.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.search,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                border: isUser ? null : Border.all(color: AppColors.border),
              ),
              child: isUser
                  ? Text(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    )
                  : _FormattedMessageText(text: message.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormattedMessageText extends StatelessWidget {
  final String text;
  const _FormattedMessageText({required this.text});

  @override
  Widget build(BuildContext context) {
    // Basic Markdown bold parser: **word**
    final parts = text.split('**');
    final spans = <TextSpan>[];

    for (int i = 0; i < parts.length; i++) {
      final isBold = i % 2 == 1;
      spans.add(
        TextSpan(
          text: parts[i],
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            height: 1.45,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }
}
