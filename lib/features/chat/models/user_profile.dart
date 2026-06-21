class UserProfileObject {
  final String id;
  final String username;
  final String status;
  final String avatarUrl;
  final bool isOnlineVisible;
  final bool typingIndicators;

  UserProfileObject({
    required this.id,
    required this.username,
    required this.status,
    required this.avatarUrl,
    this.isOnlineVisible = true,
    this.typingIndicators = true,
  });

  UserProfileObject copyWith({
    String? id,
    String? username,
    String? status,
    String? avatarUrl,
    bool? isOnlineVisible,
    bool? typingIndicators,
  }) {
    return UserProfileObject(
      id: id ?? this.id,
      username: username ?? this.username,
      status: status ?? this.status,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnlineVisible: isOnlineVisible ?? this.isOnlineVisible,
      typingIndicators: typingIndicators ?? this.typingIndicators,
    );
  }

  factory UserProfileObject.fromJson(Map<String, dynamic> json, String id) {
    return UserProfileObject(
      id: id,
      username: json['username'] ?? json['displayName'] ?? '',
      status: json['status'] ?? 'Available',
      avatarUrl: json['avatarUrl'] ?? json['photoUrl'] ?? '',
      isOnlineVisible: json['isOnlineVisible'] ?? true,
      typingIndicators: json['typingIndicators'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'status': status,
      'avatarUrl': avatarUrl,
      'isOnlineVisible': isOnlineVisible,
      'typingIndicators': typingIndicators,
    };
  }
}
