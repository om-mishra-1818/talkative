import 'package:isar/isar.dart';

part 'message_entity.g.dart';

@collection
class MessageEntity {
  MessageEntity();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String messageId; // Unique string ID from Supabase/Firestore

  @Index()
  late String chatId; // ID of the chat/conversation this belongs to

  late String text;
  
  @Index()
  late String senderId;
  
  @Index()
  late DateTime timestamp;
  
  late String textVolume; // normal, shout, whisper
  
  late String mediaType; // text, audio, image

  // For syncing logic
  bool isSynced = true;
  bool isEdited = false;
  bool isRead = false;

  // Convert to and from JSON (Supabase payload)
  factory MessageEntity.fromJson(Map<String, dynamic> json) {
    return MessageEntity()
      ..messageId = json['id'] as String
      ..chatId = json['chatId'] as String
      ..text = json['text'] as String
      ..senderId = json['senderId'] as String
      ..timestamp = DateTime.parse(json['timestamp'] as String).toLocal()
      ..textVolume = json['textVolume'] as String? ?? 'normal'
      ..mediaType = json['mediaType'] as String? ?? 'text'
      ..isEdited = json['isEdited'] as bool? ?? false
      ..isRead = json['isRead'] as bool? ?? false
      ..isSynced = true;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': messageId,
      'chatId': chatId,
      'text': text,
      'senderId': senderId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'textVolume': textVolume,
      'mediaType': mediaType,
      'isEdited': isEdited,
      'isRead': isRead,
    };
  }
}
