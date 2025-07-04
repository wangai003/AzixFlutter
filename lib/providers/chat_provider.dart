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
  
  // Load communities from Firestore
  Future<void> loadCommunities() async {
    _isLoading = true;
    notifyListeners();
    try {
      _firestore.collection('communities').snapshots().listen((snapshot) {
        _communities = snapshot.docs.map((doc) {
          final data = doc.data();
          // Parse channels and members as needed
          return Community(
            id: doc.id,
            name: data['name'] ?? '',
            description: data['description'] ?? '',
            members: (data['members'] as List?)?.length ?? 0,
            isPrivate: data['isPrivate'] ?? false,
            channels: (data['channels'] as List?)?.map((c) => Channel(
              id: c['id'],
              name: c['name'],
              messages: [], // Messages loaded separately
            )).toList() ?? [],
          );
        }).toList();
        notifyListeners();
      });
      _isLoading = false;
    } catch (e) {
      print('Error loading communities: $e');
      _isLoading = false;
      notifyListeners();
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
      final docRef = await _firestore.collection('communities').add({
        'name': name,
        'description': description,
        'isPrivate': isPrivate,
        'createdAt': DateTime.now().toIso8601String(),
        'createdBy': _chatService.currentUserId,
        'members': [_chatService.currentUserId],
        'channels': [
          {
            'id': 'general',
            'name': 'general',
          }
        ],
        'imageUrl': imageUrl,
      });
      // Optionally auto-join the creator
      await joinCommunityById(docRef.id);
    } catch (e) {
      print('Error creating community: $e');
      rethrow;
    }
  }
  
  // Join a community by ID
  Future<void> joinCommunityById(String communityId) async {
    try {
      final doc = _firestore.collection('communities').doc(communityId);
      await doc.update({
        'members': FieldValue.arrayUnion([_chatService.currentUserId])
      });
    } catch (e) {
      print('Error joining community: $e');
      rethrow;
    }
  }
  
  // Join a community (from Community object)
  Future<void> joinCommunity(Community community) async {
    await joinCommunityById(community.id);
  }
  
  // Delete a community (only by creator)
  Future<void> deleteCommunity(String communityId, {String? imageUrl}) async {
    try {
      final doc = _firestore.collection('communities').doc(communityId);
      final snapshot = await doc.get();
      if (snapshot.exists && snapshot.data()?['createdBy'] == _chatService.currentUserId) {
        // Delete image from storage if exists
        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            final ref = _storage.refFromURL(imageUrl);
            await ref.delete();
          } catch (e) {
            print('Error deleting image from storage: $e');
          }
        }
        // Delete all messages (optional: implement if storing messages in subcollections)
        // ...
        await doc.delete();
      }
    } catch (e) {
      print('Error deleting community: $e');
      rethrow;
    }
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
      });
      _replyToMessage = null;
      notifyListeners();
    } catch (e) {
      print('Error sending message: $e');
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
      print('Error toggling reaction: $e');
      rethrow;
    }
  }
}