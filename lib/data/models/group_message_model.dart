/// Model representing a group chat text message.
class GroupMessageModel {
  final String id;
  final String groupId;
  final String senderId;
  final String message;
  final DateTime createdAt;
  final String senderName;

  const GroupMessageModel({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.message,
    required this.createdAt,
    this.senderName = 'Étudiant FSEGN',
  });

  factory GroupMessageModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    String name = 'Étudiant FSEGN';
    if (json['profiles'] is Map<String, dynamic>) {
      name = json['profiles']['display_name'] as String? ?? 'Étudiant FSEGN';
    } else if (json['sender_name'] is String) {
      name = json['sender_name'] as String;
    }

    return GroupMessageModel(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      senderId: json['sender_id'] as String,
      message: json['message'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      senderName: name,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'group_id': groupId,
      'sender_id': senderId,
      'message': message.trim(),
    };
  }
}
