import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/community_screen.dart'; // Import for Message class

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Get current user display name
  String? get currentUserName => _auth.currentUser?.displayName ?? 'Anonymous User';

  // Get messages for a specific channel in a community
  Stream<List<Message>> getMessages(String communityId, String channelId) {
    return _firestore
        .collection('communities')
        .doc(communityId)
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Message.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  // Send a new message
  Future<void> sendMessage({
    required String communityId,
    required String channelId,
    required String content,
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
  }) async {
    if (currentUserId == null) return;
    
    final message = Message(
      id: '', // Will be set by Firestore
      senderId: currentUserId!,
      senderName: currentUserName!,
      content: content,
      timestamp: DateTime.now(),
      reactions: {},
      replyToId: replyToId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
    );
    
    await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .add(message.toFirestore());
  }

  // Add or remove a reaction to a message
  Future<void> toggleReaction({
    required String communityId,
    required String channelId,
    required String messageId,
    required String emoji,
  }) async {
    if (currentUserId == null) return;
    
    final messageRef = _firestore
        .collection('communities')
        .doc(communityId)
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId);
    
    return _firestore.runTransaction((transaction) async {
      final messageDoc = await transaction.get(messageRef);
      
      if (!messageDoc.exists) {
        throw Exception('Message does not exist!');
      }
      
      final messageData = messageDoc.data() as Map<String, dynamic>;
      final reactions = Map<String, List<dynamic>>.from(
        messageData['reactions'] as Map<String, dynamic>? ?? {},
      );
      
      if (!reactions.containsKey(emoji)) {
        reactions[emoji] = [currentUserId];
      } else {
        final userList = List<dynamic>.from(reactions[emoji] ?? []);
        
        if (userList.contains(currentUserId)) {
          userList.remove(currentUserId);
          if (userList.isEmpty) {
            reactions.remove(emoji);
          } else {
            reactions[emoji] = userList;
          }
        } else {
          userList.add(currentUserId);
          reactions[emoji] = userList;
        }
      }
      
      transaction.update(messageRef, {'reactions': reactions});
    });
  }

  // Get all communities
  Stream<List<Community>> getCommunities() {
    return _firestore
        .collection('communities')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) async {
            final data = doc.data();
            
            // Get channels for this community
            final channelsSnapshot = await _firestore
                .collection('communities')
                .doc(doc.id)
                .collection('channels')
                .get();
            
            final channels = await Future.wait(
              channelsSnapshot.docs.map((channelDoc) async {
                final channelData = channelDoc.data();
                
                // Get the most recent messages for this channel (limit to 20)
                final messagesSnapshot = await _firestore
                    .collection('communities')
                    .doc(doc.id)
                    .collection('channels')
                    .doc(channelDoc.id)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(20)
                    .get();
                
                final messages = messagesSnapshot.docs.map((messageDoc) {
                  return Message.fromFirestore(messageDoc.data(), messageDoc.id);
                }).toList();
                
                // Reverse to get chronological order
                messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
                
                return Channel(
                  id: channelDoc.id,
                  name: channelData['name'] ?? '',
                  messages: messages,
                );
              }).toList(),
            );
            
            return Community(
              id: doc.id,
              name: data['name'] ?? '',
              description: data['description'] ?? '',
              members: data['memberCount'] ?? 0,
              isPrivate: data['isPrivate'] ?? false,
              channels: channels,
            );
          }).toList();
        })
        .asyncMap((communities) async {
          return await Future.wait(communities);
        });
  }

  // Join a community
  Future<void> joinCommunity(String communityId) async {
    if (currentUserId == null) return;
    
    final communityRef = _firestore.collection('communities').doc(communityId);
    
    await _firestore.runTransaction((transaction) async {
      final communityDoc = await transaction.get(communityRef);
      
      if (!communityDoc.exists) {
        throw Exception('Community does not exist!');
      }
      
      final memberCount = communityDoc.data()?['memberCount'] ?? 0;
      
      transaction.update(communityRef, {'memberCount': memberCount + 1});
    });
    
    // Add user to community members
    await communityRef.collection('members').doc(currentUserId).set({
      'joinedAt': FieldValue.serverTimestamp(),
      'displayName': currentUserName,
    });
  }

  // Create a new community
  Future<String> createCommunity({
    required String name,
    required String description,
    required bool isPrivate,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    // Create the community
    final communityRef = await _firestore.collection('communities').add({
      'name': name,
      'description': description,
      'isPrivate': isPrivate,
      'memberCount': 1,
      'createdBy': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Add the creator as a member
    await communityRef.collection('members').doc(currentUserId).set({
      'joinedAt': FieldValue.serverTimestamp(),
      'displayName': currentUserName,
      'isAdmin': true,
    });
    
    // Create a default general channel
    final channelRef = await communityRef.collection('channels').add({
      'name': 'general',
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Add a welcome message
    await channelRef.collection('messages').add({
      'senderId': 'system',
      'senderName': 'System',
      'content': 'Welcome to the $name community! This is the beginning of the #general channel.',
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    });
    
    return communityRef.id;
  }
}