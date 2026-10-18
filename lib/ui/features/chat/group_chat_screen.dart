import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/group_message_model.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../core/responsive_scaffold.dart';
import '../../core/ui_helpers.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupTitle;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupTitle,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<List<GroupMessageModel>>? _subscription;
  List<GroupMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startListening() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _subscription = ChatRepository.instance
        .streamMessages(widget.groupId)
        .listen(
          (list) {
            if (mounted) {
              setState(() {
                _messages = list;
                _isLoading = false;
              });
              _scrollToBottom();
            }
          },
          onError: (err) {
            if (mounted) {
              setState(() {
                _errorMessage = err.toString();
                _isLoading = false;
              });
            }
          },
        );
  }

  Future<void> _manualRefresh() async {
    try {
      final list = await ChatRepository.instance.fetchMessages(widget.groupId);
      if (mounted) {
        setState(() {
          _messages = list;
        });
        _scrollToBottom();
        UiHelpers.showSnackBar(context, 'Messages actualisés.');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          'Erreur d’actualisation : $e',
          isError: true,
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ChatRepository.instance.sendMessage(widget.groupId, text);
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          'Impossible d’envoyer le message : $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthRepository.instance.currentUserId;

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Chat réservé aux membres inscrits',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser manuellement',
            onPressed: _manualRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Notice banner explaining Realtime / Fallback
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: AppTheme.tealLight,
            child: Row(
              children: const [
                Icon(Icons.bolt, size: 14, color: AppTheme.tealAccent),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Messagerie instantanée Supabase Realtime avec secours manuel.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: AppTheme.alertError.withAlpha(25),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppTheme.alertError,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connexion temps réel limitée : ${_errorMessage!}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.alertError,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? UiHelpers.buildEmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'Aucun message pour l’instant',
                    description:
                        'Présentez-vous et organisez le travail avec vos camarades !',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.senderId == currentUserId;

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? AppTheme.primaryNavy : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(14),
                              topRight: const Radius.circular(14),
                              bottomLeft: Radius.circular(isMe ? 14 : 2),
                              bottomRight: Radius.circular(isMe ? 2 : 14),
                            ),
                            border: isMe
                                ? null
                                : Border.all(color: AppTheme.borderSubtle),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(10),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Text(
                                    msg.senderName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.tealAccent,
                                    ),
                                  ),
                                ),
                              Text(
                                msg.message,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isMe
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                UiHelpers.formatTime(msg.createdAt),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe
                                      ? Colors.white70
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Message Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Écrire un message...',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                  ),
                  onPressed: _isSending ? null : _handleSend,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, size: 18, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
