import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/community_screen.dart';
import '../services/chat_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  
  List<Community> _communities = [];
  List<Community> _discoverCommunities = [];
  bool _isLoading = false;
  int _selectedCommunityIndex = 0;
  int _selectedChannelIndex = 0;
  Message? _replyToMessage;
  
  // Getters
  List<Community> get communities => _communities;
  set communities(List<Community> value) => _communities = value;
  
  List<Community> get discoverCommunities => _discoverCommunities;
  set discoverCommunities(List<Community> value) => _discoverCommunities = value;
  
  bool get isLoading => _isLoading;
  int get selectedCommunityIndex => _selectedCommunityIndex;
  int get selectedChannelIndex => _selectedChannelIndex;
  Message? get replyToMessage => _replyToMessage;
  
  // Get selected community
  Community? get selectedCommunity {
    if (_communities.isEmpty || _selectedCommunityIndex >= _communities.length) {
      return null;
    }
    return _communities[_selectedCommunityIndex];
  }
  
  // Get selected channel
  Channel? get selectedChannel {
    if (selectedCommunity == null || 
        selectedCommunity!.channels.isEmpty || 
        _selectedChannelIndex >= selectedCommunity!.channels.length) {
      return null;
    }
    return selectedCommunity!.channels[_selectedChannelIndex];
  }
  
  // Load communities from Firestore - ONLY communities user has joined
  Future<void> loadCommunities() async {
    _isLoading = true;
    notifyListeners();
    try {
      final currentUserId = _chatService.currentUserId;
      
      // Listen to communities where user is a member
      _firestore
          .collection('communities')
          .where('members', arrayContains: currentUserId)
          .snapshots()
          .listen((snapshot) {
        _communities = snapshot.docs.map((doc) {
          final data = doc.data();
          return Community(
            id: doc.id,
            name: data['name'] ?? '',
            description: data['description'] ?? '',
            members: (data['members'] as List?)?.length ?? 0,
            isPrivate: data['isPrivate'] ?? false,
            createdBy: data['createdBy'] ?? '',
            imageUrl: data['imageUrl'],
            channels: (data['channels'] as List?)?.map((c) => Channel(
              id: c['id'],
              name: c['name'],
              messages: [], // Messages loaded separately
            )).toList() ?? [],
          );
        }).toList();
        notifyListeners();
      });
      
      // Load discover communities (communities user hasn't joined)
      _loadDiscoverCommunities();
      
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Load discover communities (communities user hasn't joined)
  Future<void> _loadDiscoverCommunities() async {
    try {
      final currentUserId = _chatService.currentUserId;
      
      _firestore
          .collection('communities')
          .where('isPrivate', isEqualTo: false) // Only public communities
          .snapshots()
          .listen((snapshot) {
        _discoverCommunities = snapshot.docs.where((doc) {
          final data = doc.data();
          final members = List<String>.from(data['members'] ?? []);
          return !members.contains(currentUserId); // Not already joined
        }).map((doc) {
          final data = doc.data();
          return Community(
            id: doc.id,
            name: data['name'] ?? '',
            description: data['description'] ?? '',
            members: (data['members'] as List?)?.length ?? 0,
            isPrivate: data['isPrivate'] ?? false,
            createdBy: data['createdBy'] ?? '',
            imageUrl: data['imageUrl'],
            channels: (data['channels'] as List?)?.map((c) => Channel(
              id: c['id'],
              name: c['name'],
              messages: [],
            )).toList() ?? [],
          );
        }).toList();
        notifyListeners();
      });
    } catch (e) {
    }
  }
  
  // Set selected community
  void setSelectedCommunity(int index) {
    if (index >= 0 && index < _communities.length) {
      _selectedCommunityIndex = index;
      _selectedChannelIndex = 0; // Reset channel index when changing community
      notifyListeners();
    }
  }
  
  // Set selected channel
  void setSelectedChannel(int index) {
    if (selectedCommunity != null && 
        index >= 0 && 
        index < selectedCommunity!.channels.length) {
      _selectedChannelIndex = index;
      notifyListeners();
    }
  }
  
  // Set reply to message
  void setReplyToMessage(Message? message) {
    _replyToMessage = message;
    notifyListeners();
  }
  
  // Clear reply to message
  void clearReplyToMessage() {
    _replyToMessage = null;
    notifyListeners();
  }
  
  // Create a new community in Firestore
  Future<void> createCommunity({
    required String name,
    required String description,
    required bool isPrivate,
    File? imageFile,
  }) async {
    try {
      String? imageUrl;
      if (imageFile != null) {
        final ref = _storage.ref().child('community_images/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}');
        final uploadTask = await ref.putFile(imageFile);
        imageUrl = await uploadTask.ref.getDownloadURL();
      }
      
      final currentUserId = _chatService.currentUserId;
      final docRef = await _firestore.collection('communities').add({
        'name': name,
        'description': description,
        'isPrivate': isPrivate,
        'createdAt': DateTime.now().toIso8601String(),
        'createdBy': currentUserId,
        'members': [currentUserId], // Creator automatically joins
        'channels': [
          {
            'id': 'general',
            'name': 'general',
          }
        ],
        'imageUrl': imageUrl,
      });
      
      // Refresh communities list
      await loadCommunities();
    } catch (e) {
      rethrow;
    }
  }
  
  // Join a community by ID
  Future<void> joinCommunityById(String communityId) async {
    try {
      final currentUserId = _chatService.currentUserId;
      final doc = _firestore.collection('communities').doc(communityId);
      
      // Check if user is already a member
      final snapshot = await doc.get();
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final members = List<String>.from(data['members'] ?? []);
        
        if (!members.contains(currentUserId)) {
          await doc.update({
            'members': FieldValue.arrayUnion([currentUserId])
          });
          
          // Refresh communities list
          await loadCommunities();
        }
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Join a community (from Community object)
  Future<void> joinCommunity(Community community) async {
    await joinCommunityById(community.id);
  }
  
  // Leave a community
  Future<void> leaveCommunity(String communityId) async {
    try {
      final currentUserId = _chatService.currentUserId;
      final doc = _firestore.collection('communities').doc(communityId);
      
      // Check if user is the creator
      final snapshot = await doc.get();
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final createdBy = data['createdBy'];
        
        if (createdBy == currentUserId) {
          throw Exception('Cannot leave a community you created. Delete it instead.');
        }
        
        await doc.update({
          'members': FieldValue.arrayRemove([currentUserId])
        });
        
        // Refresh communities list
        await loadCommunities();
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Delete a community (only by creator)
  Future<void> deleteCommunity(String communityId, {String? imageUrl}) async {
    try {
      final currentUserId = _chatService.currentUserId;
      final doc = _firestore.collection('communities').doc(communityId);
      final snapshot = await doc.get();
      
      if (snapshot.exists && snapshot.data()?['createdBy'] == currentUserId) {
        // Delete image from storage if exists
        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            final ref = _storage.refFromURL(imageUrl);
            await ref.delete();
          } catch (e) {
          }
        }
        
        // Delete all messages in subcollections
        final channelsSnapshot = await _firestore
            .collection('communities')
            .doc(communityId)
            .collection('channels')
            .get();
        for (final channelDoc in channelsSnapshot.docs) {
          final messagesSnapshot = await channelDoc.reference.collection('messages').get();
          for (final messageDoc in messagesSnapshot.docs) {
            await messageDoc.reference.delete();
          }
          await channelDoc.reference.delete();
        }
        
        await doc.delete();
        
        // Refresh communities list
        await loadCommunities();
      } else {
        throw Exception('You can only delete communities you created.');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Mark all messages as read in a channel for the current user
  Future<void> markMessagesAsRead(String communityId, String channelId, String userId) async {
    final messagesRef = _firestore
        .collection('communities')
        .doc(communityId)
        .collection('channels')
        .doc(channelId)
        .collection('messages');
    final snapshot = await messagesRef.where('readBy', whereNotIn: [userId]).get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final readBy = List<String>.from(data['readBy'] ?? []);
      if (!readBy.contains(userId)) {
        await doc.reference.update({
          'readBy': FieldValue.arrayUnion([userId])
        });
      }
    }
  }

  // Get unread count for a channel
  Future<int> getUnreadCount(String communityId, String channelId, String userId) async {
    final messagesRef = _firestore
        .collection('communities')
        .doc(communityId)
        .collection('channels')
        .doc(channelId)
        .collection('messages');
    final snapshot = await messagesRef.where('readBy', whereNotIn: [userId]).get();
    return snapshot.docs.length;
  }
  
  // Send a text or image message
  Future<void> sendMessage(String content, {File? imageFile}) async {
    if ((content.isEmpty && imageFile == null) || selectedCommunity == null || selectedChannel == null) {
      return;
    }
    try {
      String? imageUrl;
      if (imageFile != null) {
        if (await imageFile.length() > 5 * 1024 * 1024) {
          throw Exception('Image size exceeds 5MB');
        }
        final ref = _storage.ref().child('chat_images/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}');
        final uploadTask = await ref.putFile(imageFile);
        imageUrl = await uploadTask.ref.getDownloadURL();
      }
      final messagesRef = _firestore
        .collection('communities')
        .doc(selectedCommunity!.id)
        .collection('channels')
        .doc(selectedChannel!.id)
        .collection('messages');
      await messagesRef.add({
        'senderId': _chatService.currentUserId,
        'senderName': _chatService.currentUserName,
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
        'reactions': {},
        'imageUrl': imageUrl,
        'replyToId': _replyToMessage?.id,
        'replyToContent': _replyToMessage?.content,
        'replyToSenderName': _replyToMessage?.senderName,
        'readBy': [_chatService.currentUserId], // Mark as read by sender
      });
      _replyToMessage = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  // Pick image for chat message
  Future<File?> pickImageForMessage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      final file = File(picked.path);
      if (await file.length() > 5 * 1024 * 1024) {
        // File too large
        return null;
      }
      return file;
    }
    return null;
  }
  
  // Toggle a reaction on a message
  Future<void> toggleReaction(Message message, String emoji) async {
    if (selectedCommunity == null || selectedChannel == null) {
      return;
    }
    
    try {
      final currentUserId = _chatService.currentUserId ?? 'current_user';
      
      if (!message.reactions.containsKey(emoji)) {
        message.reactions[emoji] = [currentUserId];
      } else {
        final userList = message.reactions[emoji]!;
        
        if (userList.contains(currentUserId)) {
          userList.remove(currentUserId);
          if (userList.isEmpty) {
            message.reactions.remove(emoji);
          }
        } else {
          userList.add(currentUserId);
        }
      }
      
      // In a real app, this would update Firestore
      // await _chatService.toggleReaction(
      //   communityId: selectedCommunity!.id,
      //   channelId: selectedChannel!.id,
      //   messageId: message.id,
      //   emoji: emoji,
      // );
      
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}