import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/chat/bloc/chat_bloc.dart';
import 'package:shear_heaven_pet_spa/src/chat/models/chat_message_model.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';

class ChatPageMobile extends StatefulWidget {
  const ChatPageMobile({super.key});

  @override
  State<ChatPageMobile> createState() => _ChatPageMobileState();
}

class _ChatPageMobileState extends State<ChatPageMobile> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (ServicesLocator.sessionService.isLoggedIn) {
      context.read<ChatBloc>().add(const InitializeChat());
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage({String? customMessage, bool useAssistant = true}) async {
    final text = (customMessage ?? _textController.text).trim();
    if (text.isEmpty) return;

    _textController.clear();

    if (text.toLowerCase() == 'view services') {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      context.pushNamed(RouteNames.services);
      return;
    } else if (text.toLowerCase() == 'my bookings' || text.toLowerCase() == 'view my bookings') {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      context.pushNamed(RouteNames.myBookings);
      return;
    }

    if (mounted) {
      context.read<ChatBloc>().add(SendMessageEvent(text, useAssistant: useAssistant));
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ServicesLocator.sessionService.isLoggedIn) {
      return PopScope(
        canPop: context.canPop(),
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          context.goNamed(RouteNames.home);
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.goNamed(RouteNames.home);
                }
              },
            ),
            title: Text(
              'Chat Support',
              style: AppFonts.parkinsans(
                size: 20,
                weight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            centerTitle: false,
          ),
          body: _buildGuestState(),
        ),
      );
    }
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.goNamed(RouteNames.home);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.goNamed(RouteNames.home);
              }
            },
          ),
          title: Row(
            children: [
              Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: SvgPicture.asset(
                  'assets/images/common/logo.svg',
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.pets, size: 20, color: Colors.black),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shear Heaven Assistant',
                  style: AppFonts.parkinsans(
                    size: 16,
                    weight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF34C759),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Always here to help',
                      style: AppFonts.poppins(
                        size: 11,
                        weight: FontWeight.w500,
                        color: const Color(0xFF34C759),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: BlocConsumer<ChatBloc, ChatState>(
        listener: (context, state) {
          if (state.status == ChatStatus.failure && state.message.isNotEmpty) {
            ToastUtil.showErrorToast(context, state.message);
          } else if (state.status == ChatStatus.success || state.status == ChatStatus.loaded) {
            _scrollToBottom();
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              Expanded(
                child: _buildChatBody(state),
              ),
              _buildInputArea(state),
            ],
          );
        },
      ),
    ),
    );
  }

  Widget _buildChatBody(ChatState state) {
    if (state.status == ChatStatus.loading && state.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E1E1E), strokeWidth: 2.5),
      );
    }

    if (state.status == ChatStatus.failure && state.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(
                'Could not load chat history. Please try again.',
                style: AppFonts.poppins(size: 14, color: const Color(0xFF1E1E1E)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E1E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  context.read<ChatBloc>().add(const InitializeChat());
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // Default welcoming bubble if chat has no history
        if (state.messages.isEmpty) ...[
          _buildAssistantBubble(
            ChatMessage(
              id: 'welcome',
              sender: 'assistant',
              message: "Hi! 👋 I'm here to help.\nWhat would you like to do?",
              isUser: false,
              createdAt: DateTime.now(),
            ),
          ),
          const SizedBox(height: 12),
          _buildWrap([
            _buildInteractiveChip("Book an appointment", () => _handleSendMessage(customMessage: "Book an appointment")),
            _buildInteractiveChip("View Services", () => _handleSendMessage(customMessage: "View Services")),
            _buildInteractiveChip("What are your store hours?", () => _handleSendMessage(customMessage: "What are your store hours?")),
            _buildInteractiveChip("Available Offers", () => _handleSendMessage(customMessage: "What offers and discounts are available?")),
          ]),
          const SizedBox(height: 24),
        ],

        // Render dynamic messages from history / session
        ...state.messages.map((msg) {
          if (msg.isUser) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildUserBubble(msg),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildAssistantBubble(msg),
            );
          }
        }),

        // Typing indicator when waiting for assistant response
        if (state.isTyping || state.status == ChatStatus.sending) ...[
          _buildTypingIndicator(),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  String _formatMessageTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
    if (isToday) {
      return DateFormat('h:mm a').format(local);
    }
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = local.year == yesterday.year && local.month == yesterday.month && local.day == yesterday.day;
    if (isYesterday) {
      return 'Yesterday, ${DateFormat('h:mm a').format(local)}';
    }
    return DateFormat('MMM d, h:mm a').format(local);
  }

  Widget _buildAssistantBubble(ChatMessage msg) {
    final text = cleanChatMessage(msg.message);
    final timeStr = _formatMessageTime(msg.createdAt);
    final isGroomer = msg.sender.toLowerCase() == 'groomer';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 8, top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: isGroomer
                ? const Icon(Icons.content_cut, size: 16, color: Color(0xFF0F766E))
                : SvgPicture.asset(
                    'assets/images/common/logo.svg',
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.pets, size: 16, color: Colors.black),
                  ),
          ),
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isGroomer) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    'Groomer',
                    style: AppFonts.poppins(
                      size: 11,
                      weight: FontWeight.w600,
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: AppFonts.poppins(size: 14, color: Colors.black, height: 1.4),
                    ),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          timeStr,
                          style: AppFonts.poppins(
                            size: 10.5,
                            color: const Color(0xFF8E8E93),
                            weight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildUserBubble(ChatMessage msg, {bool isEdit = false, bool isConfirm = false}) {
    final text = cleanChatMessage(msg.message);
    final timeStr = _formatMessageTime(msg.createdAt);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(width: 48),
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isEdit) ...[
                      const Icon(Icons.edit, color: Color(0xFFF2A900), size: 16),
                      const SizedBox(width: 6),
                    ],
                    if (isConfirm) ...[
                      const Icon(Icons.check_box, color: Color(0xFF34C759), size: 16),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        text,
                        style: AppFonts.poppins(size: 14, color: Colors.white, weight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: AppFonts.poppins(
                      size: 10.5,
                      color: Colors.white.withValues(alpha: 0.6),
                      weight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: SvgPicture.asset(
              'assets/images/common/logo.svg',
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.pets, size: 16, color: Colors.black),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFEEEEEE),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Assistant is typing...',
                style: AppFonts.poppins(size: 12.5, color: const Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWrap(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(left: 40),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: children,
      ),
    );
  }

  Widget _buildInteractiveChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Text(
          label,
          style: AppFonts.poppins(
            size: 13,
            weight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(ChatState state) {
    final isSending = state.isTyping || state.status == ChatStatus.sending;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    // When keyboard is open: snug 8px padding directly above the keyboard.
    // When keyboard is closed: 112px (dock 78 + margin 34) + 12px spacing = 124px.
    final double bottomPadding = keyboardOpen ? 8.0 : 124.0;

    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        padding: const EdgeInsets.only(left: 20, right: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                textInputAction: TextInputAction.send,
                onSubmitted: (value) => _handleSendMessage(),
                style: AppFonts.poppins(
                  size: 14,
                  weight: FontWeight.w400,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: AppFonts.poppins(size: 14, color: const Color(0xFFAFAFAF)),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            GestureDetector(
              onTap: isSending ? null : () => _handleSendMessage(),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  shape: BoxShape.circle,
                ),
                child: isSending
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 46,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign In to Chat with Support',
              style: AppFonts.parkinsans(
                size: 20,
                weight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Have questions about services or an existing booking? Sign in to chat directly with our team.',
              style: AppFonts.poppins(
                size: 14,
                color: const Color(0xFF6B7280),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(60),
                  ),
                ),
                onPressed: () => context.pushNamed(RouteNames.login),
                child: Text(
                  'Sign In / Register',
                  style: AppFonts.parkinsans(
                    size: 16,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
