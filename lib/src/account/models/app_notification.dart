class AppNotification {
  final int id;
  final int? userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime? createdAt;
  final Map<String, dynamic>? metadata;

  const AppNotification({
    required this.id,
    this.userId,
    required this.title,
    required this.message,
    this.type = 'general',
    this.isRead = false,
    this.createdAt,
    this.metadata,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    int parsedId = 0;
    final rawId = json['id'] ?? json['notificationId'] ?? json['notification_id'] ?? json['_id'];
    if (rawId != null) {
      parsedId = int.tryParse(rawId.toString()) ?? 0;
    }
    if (parsedId == 0 && (json['bookingId'] != null || json['booking_id'] != null)) {
      final bId = json['bookingId'] ?? json['booking_id'];
      parsedId = int.tryParse(bId.toString()) ?? 0;
    }

    int? parsedUserId;
    if (json['userId'] != null) {
      parsedUserId = int.tryParse(json['userId'].toString());
    }

    final rawTitle = json['title'] ?? json['subject'] ?? json['heading'] ?? '';
    final rawMessage = json['message'] ?? json['body'] ?? json['description'] ?? json['text'] ?? '';
    final rawType = json['type']?.toString() ?? 'general';

    final rawIsRead = json['isRead'] ?? json['read'] ?? false;
    final isReadBool = rawIsRead is bool
        ? rawIsRead
        : (rawIsRead.toString().toLowerCase() == 'true' || rawIsRead.toString() == '1');

    DateTime? parsedCreatedAt;
    final rawCreatedAt = json['createdAt'] ?? json['created_at'] ?? json['timestamp'];
    if (rawCreatedAt != null) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt.toString());
    }

    Map<String, dynamic> parsedMetadata = {};
    if (json['data'] is Map) {
      parsedMetadata.addAll(Map<String, dynamic>.from(json['data'] as Map));
    }
    if (json['metadata'] is Map) {
      parsedMetadata.addAll(Map<String, dynamic>.from(json['metadata'] as Map));
    }

    // Retain top-level booking/entity keys in metadata
    for (final key in [
      'bookingId',
      'booking_id',
      'entityId',
      'entity_id',
      'petId',
      'petName',
      'groomerId',
      'groomerName',
      'status',
      'bookingDate',
      'startTime',
      'endTime'
    ]) {
      if (json.containsKey(key) && !parsedMetadata.containsKey(key)) {
        parsedMetadata[key] = json[key];
      }
    }
    if (!parsedMetadata.containsKey('bookingId') && parsedMetadata.containsKey('entityId')) {
      parsedMetadata['bookingId'] = parsedMetadata['entityId'];
    }

    return AppNotification(
      id: parsedId,
      userId: parsedUserId,
      title: rawTitle.toString(),
      message: rawMessage.toString(),
      type: rawType,
      isRead: isReadBool,
      createdAt: parsedCreatedAt,
      metadata: parsedMetadata.isNotEmpty ? parsedMetadata : null,
    );
  }

  AppNotification copyWith({
    int? id,
    int? userId,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (userId != null) 'userId': userId,
    'title': title,
    'message': message,
    'type': type,
    'isRead': isRead,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (metadata != null) 'data': metadata,
  };
}

