import 'package:isar/isar.dart';

part 'chat_entity.g.dart';

@collection
class ChatEntity {
  ChatEntity();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String chatId; // Unique string ID for the conversation

  @Index()
  late String otherUserId;

  late String name;
  
  late String avatarUrl;
  
  late bool isOnline;
  
  late String status;
  
  late String phoneNumber;
  
  late String lastMessage;
  
  late String mediaType;
  
  @Index()
  DateTime? time;
  
  late int unreadCount;
  
  late bool hasActiveCall;
  
  late bool isBlocked;

  factory ChatEntity.fromJson(Map<String, dynamic> json) {
    return ChatEntity()
      ..chatId = json['id'] as String
      ..otherUserId = json['otherUserId'] as String? ?? ''
      ..name = json['name'] as String? ?? 'Unknown'
      ..avatarUrl = json['avatarUrl'] as String? ?? ''
      ..isOnline = json['isOnline'] as bool? ?? false
      ..status = json['status'] as String? ?? 'Offline'
      ..phoneNumber = json['phoneNumber'] as String? ?? ''
      ..lastMessage = json['lastMessage'] as String? ?? ''
      ..mediaType = json['mediaType'] as String? ?? 'text'
      ..time = json['time'] != null ? DateTime.parse(json['time'] as String).toLocal() : null
      ..unreadCount = json['unreadCount'] as int? ?? 0
      ..hasActiveCall = json['hasActiveCall'] as bool? ?? false
      ..isBlocked = json['isBlocked'] as bool? ?? false;
  }

  ChatEntity copyWith({
    String? chatId,
    String? otherUserId,
    String? name,
    String? avatarUrl,
    bool? isOnline,
    String? status,
    String? phoneNumber,
    String? lastMessage,
    String? mediaType,
    DateTime? time,
    int? unreadCount,
    bool? hasActiveCall,
    bool? isBlocked,
  }) {
    return ChatEntity()
      ..id = this.id // Isar internal id
      ..chatId = chatId ?? this.chatId
      ..otherUserId = otherUserId ?? this.otherUserId
      ..name = name ?? this.name
      ..avatarUrl = avatarUrl ?? this.avatarUrl
      ..isOnline = isOnline ?? this.isOnline
      ..status = status ?? this.status
      ..phoneNumber = phoneNumber ?? this.phoneNumber
      ..lastMessage = lastMessage ?? this.lastMessage
      ..mediaType = mediaType ?? this.mediaType
      ..time = time ?? this.time
      ..unreadCount = unreadCount ?? this.unreadCount
      ..hasActiveCall = hasActiveCall ?? this.hasActiveCall
      ..isBlocked = isBlocked ?? this.isBlocked;
  }
}
