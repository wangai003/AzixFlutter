class OrderMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;

  OrderMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
  });

  factory OrderMessage.fromJson(Map<String, dynamic> json, String id) {
    return OrderMessage(
      id: id,
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      content: json['content'] ?? '',
      timestamp: json['timestamp'] is DateTime
          ? json['timestamp']
          : (json['timestamp']?.toDate() ?? DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': timestamp,
    };
  }
} 