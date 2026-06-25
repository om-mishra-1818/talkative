class MessageModel {
  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;
  final String textVolume; // normal, shout, whisper

  MessageModel({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    this.textVolume = 'normal',
  });

  factory MessageModel.fromJson(Map<String, dynamic> data, String docId) {
    return MessageModel(
      id: docId,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      timestamp: data['timestamp'] != null 
          ? DateTime.parse(data['timestamp']).toLocal() 
          : DateTime.now(),
      textVolume: data['textVolume'] ?? 'normal',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderId': senderId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'textVolume': textVolume,
    };
  }
}
