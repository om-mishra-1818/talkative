import 'media_type.dart';

class ChatModel {
  final String id;
  final String otherUserId;
  final String name;
  final String avatarUrl;
  final bool isOnline;
  final String status;
  final String phoneNumber;
  final String lastMessage;
  final MediaType mediaType;
  final DateTime? time;
  final int unreadCount;
  final bool hasActiveCall;
  final String? lastMessageType;
  final bool isBlocked;

  ChatModel({
    required this.id,
    required this.otherUserId,
    required this.name,
    required this.avatarUrl,
    this.isOnline = false,
    this.status = 'Offline',
    this.phoneNumber = '',
    this.lastMessage = '',
    this.mediaType = MediaType.text,
    this.time,
    this.unreadCount = 0,
    this.hasActiveCall = false,
    this.lastMessageType,
    this.isBlocked = false,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json, String docId) {
    return ChatModel(
      id: docId,
      otherUserId: json['otherUserId'] ?? '',
      name: json['name'] ?? 'Unknown',
      avatarUrl: json['avatarUrl'] ?? '',
      isOnline: json['isOnline'] ?? false,
      status: json['status'] ?? 'Offline',
      phoneNumber: json['phoneNumber'] ?? '',
      lastMessage: json['lastMessage'] ?? '',
      mediaType: MediaTypeExt.fromString(json['mediaType'] ?? 'text'),
      time: json['time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['time'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      hasActiveCall: json['hasActiveCall'] ?? false,
      lastMessageType: json['lastMessageType'],
      isBlocked: json['is_blocked'] ?? false,
    );
  }

  ChatModel copyWith({
    String? id,
    String? otherUserId,
    String? name,
    String? avatarUrl,
    bool? isOnline,
    String? status,
    String? phoneNumber,
    String? lastMessage,
    MediaType? mediaType,
    DateTime? time,
    int? unreadCount,
    bool? hasActiveCall,
    String? lastMessageType,
    bool? isBlocked,
  }) {
    return ChatModel(
      id: id ?? this.id,
      otherUserId: otherUserId ?? this.otherUserId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      lastMessage: lastMessage ?? this.lastMessage,
      mediaType: mediaType ?? this.mediaType,
      time: time ?? this.time,
      unreadCount: unreadCount ?? this.unreadCount,
      hasActiveCall: hasActiveCall ?? this.hasActiveCall,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'otherUserId': otherUserId,
      'name': name,
      'avatarUrl': avatarUrl,
      'isOnline': isOnline,
      'status': status,
      'phoneNumber': phoneNumber,
      'lastMessage': lastMessage,
      'mediaType': mediaType.name,
      'time': time?.millisecondsSinceEpoch,
      'unreadCount': unreadCount,
      'hasActiveCall': hasActiveCall,
      'lastMessageType': lastMessageType,
      'is_blocked': isBlocked,
    };
  }
}
