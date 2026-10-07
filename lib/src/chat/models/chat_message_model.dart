import 'dart:convert';

/// Cleans raw chat messages, stripping any serialized JSON envelopes,
/// object toString dumps, or field name prefixes (id, message, createdAt, etc.)
/// and returns purely the human-readable text.
String cleanChatMessage(dynamic raw) {
  if (raw == null) return '';
  if (raw is Map) {
    final candidates = [
      raw['message'],
      raw['text'],
      raw['content'],
      raw['body'],
      raw['reply'],
      raw['response'],
      raw['msg'],
      raw['data'],
    ];
    for (final c in candidates) {
      if (c != null && c != raw) {
        final cleaned = cleanChatMessage(c);
        if (cleaned.isNotEmpty) return cleaned;
      }
    }
    return '';
  }

  String str = raw.toString().trim();
  if (str.isEmpty) return '';

  // Case 1: Valid JSON string
  if ((str.startsWith('{') && str.endsWith('}')) || (str.startsWith('[') && str.endsWith(']'))) {
    try {
      final decoded = jsonDecode(str);
      if (decoded is Map) {
        final cleaned = cleanChatMessage(decoded);
        if (cleaned.isNotEmpty) return cleaned;
      } else if (decoded is List && decoded.isNotEmpty) {
        final cleaned = cleanChatMessage(decoded.first);
        if (cleaned.isNotEmpty) return cleaned;
      }
    } catch (_) {}
  }

  // Case 2: Stringified Dart Map / object representation, e.g.
  // "{id: 1, message: Hello world, createdAt: 2026-09-22...}"
  if (str.startsWith('{') && str.endsWith('}')) {
    final inner = str.substring(1, str.length - 1).trim();
    final match = RegExp(
      r'(?:message|text|content|body|reply|response|msg)\s*[:=]\s*(.+?)(?:,\s*(?:id|createdAt|created_at|sender|role|isUser|is_user|updatedAt|updated_at)|$)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(inner);
    if (match != null && match.group(1) != null) {
      final extracted = match.group(1)!.trim();
      if (extracted.isNotEmpty) {
        return cleanChatMessage(extracted);
      }
    }
  }

  // Case 3: Line-based or comma-separated field names like "id: 1, message: Hello, createdAt: ..."
  if (str.contains('message:') || str.contains('message :') || str.contains('"message":') || str.contains("'message':")) {
    final match = RegExp(
      r'(?:^|[\n,;])\s*(?:"message"|\x27message\x27|message)\s*[:=]\s*(.+?)(?:[\n,;]\s*(?:"id"|\x27id\x27|id|createdAt|created_at|sender|role)|$)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(str);
    if (match != null && match.group(1) != null) {
      final extracted = match.group(1)!.trim();
      if (extracted.isNotEmpty) {
        return cleanChatMessage(extracted);
      }
    }
  }

  // Strip leading/trailing surrounding quotes if present
  if ((str.startsWith('"') && str.endsWith('"') && str.length >= 2) ||
      (str.startsWith("'") && str.endsWith("'") && str.length >= 2)) {
    str = str.substring(1, str.length - 1).trim();
  }

  return str;
}

class ChatMessage {
  final String id;
  final String sender; // 'user', 'assistant', 'groomer', 'agent', 'support'
  final String message;
  final DateTime? createdAt;
  final bool isUser;

  ChatMessage({
    required this.id,
    required this.sender,
    required String message,
    this.createdAt,
    required this.isUser,
  }) : message = cleanChatMessage(message);

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    var id = (json['id'] ??
            json['_id'] ??
            json['messageId'] ??
            json['message_id'] ??
            json['chatId'] ??
            json['msgId'] ??
            '')
        .toString();
    if (id.isEmpty || id == 'null') {
      id = DateTime.now().millisecondsSinceEpoch.toString();
    }

    final rawSender = (json['sender'] ??
            json['role'] ??
            json['from'] ??
            json['senderType'] ??
            json['sender_type'] ??
            'assistant')
        .toString()
        .toLowerCase();
    final isFromUser = rawSender == 'user' ||
        rawSender == 'customer' ||
        json['isUser'] == true ||
        json['is_user'] == true;

    final rawMsg = json['message'] ??
        json['text'] ??
        json['content'] ??
        json['body'] ??
        json['reply'] ??
        json['response'] ??
        json['msg'] ??
        json['data'] ??
        '';
    final cleanMsg = cleanChatMessage(rawMsg);

    DateTime? dt;
    final rawDate = json['createdAt'] ??
        json['timestamp'] ??
        json['created_at'] ??
        json['date'] ??
        json['updatedAt'] ??
        json['updated_at'] ??
        json['time'];

    if (rawDate != null) {
      if (rawDate is DateTime) {
        dt = rawDate.toLocal();
      } else if (rawDate is num) {
        final val = rawDate.toInt();
        if (val > 10000000000) {
          dt = DateTime.fromMillisecondsSinceEpoch(val).toLocal();
        } else {
          dt = DateTime.fromMillisecondsSinceEpoch(val * 1000).toLocal();
        }
      } else {
        dt = DateTime.tryParse(rawDate.toString())?.toLocal();
      }
    }
    dt ??= DateTime.now();

    return ChatMessage(
      id: id,
      sender: isFromUser ? 'user' : (rawSender.isNotEmpty && rawSender != 'null' ? rawSender : 'assistant'),
      message: cleanMsg,
      createdAt: dt,
      isUser: isFromUser,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'message': message,
      'createdAt': createdAt?.toIso8601String(),
      'isUser': isUser,
    };
  }
}
