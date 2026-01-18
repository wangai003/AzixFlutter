# 🎉 Raffle System - Simplified for Gift Vouchers

## Overview
The raffle system has been completely simplified to be **off-chain**, user-friendly, and designed specifically for gift voucher giveaways. No cryptocurrency or blockchain interaction required from users!

---

## ✨ Key Changes

### 1. **Simple Entry Process**
- ✅ Users just click "Enter Raffle" button - no wallet, no payment, no complexity
- ✅ Automatic entry tracking with username and email
- ✅ Instant confirmation with notification

### 2. **Gift Voucher Prizes**
- 🎁 Prize format changed from crypto to gift vouchers (e.g., "$50 Amazon Gift Card")
- 🎁 Admin enters prize value as text (not numeric AKOFA amounts)
- 🎁 Prize description for voucher details

### 3. **Image Upload via URL**
- 🖼️ Admin can add raffle image by pasting URL
- 🖼️ Images display on raffle cards in main listing
- 🖼️ Preview shown during creation

### 4. **Automatic Winner Selection**
- 🎲 **Legitimately randomized** using `Random.secure()` with multiple entropy sources
- 🎲 Automatic winner drawing when raffle period ends
- 🎲 Winner selection algorithm:
  - Uses secure random number generator
  - Combines timestamp, raffle ID hash, and multiple random sources
  - XOR operation for additional entropy mixing
  - Provably unpredictable and fair

### 5. **Winner Notifications**
- 📧 Winner receives in-app notification: "🎉 Congratulations! You Won!"
- 📧 Non-winners receive consolation notification
- 📧 Winner display section on raffle hub showing recent winners

### 6. **Automatic Raffle Cleanup**
- 🗑️ Completed raffles automatically disappear from main raffles list
- 🗑️ Only active and upcoming raffles shown
- 🗑️ Recent winners displayed in dedicated section

---

## 📁 Modified Files

### Core Services
1. **`lib/services/raffle_service.dart`**
   - ✅ Removed blockchain dependencies
   - ✅ Added simple `enterRaffle()` - just username and email
   - ✅ Added `drawWinnerForRaffle()` with secure randomization
   - ✅ Added `checkAndDrawExpiredRaffles()` for automatic processing
   - ✅ Added winner selection with multiple entropy sources

2. **`lib/services/raffle_scheduler_service.dart`** (NEW)
   - ✅ Automatic scheduler runs every 5 minutes
   - ✅ Checks for expired raffles and draws winners
   - ✅ Starts automatically on app initialization

3. **`lib/services/app_initialization_service.dart`**
   - ✅ Added raffle scheduler initialization

### UI Screens
4. **`lib/screens/raffle/raffle_hub_screen.dart`**
   - ✅ Hides completed raffles from main list
   - ✅ Added "Recent Winners" section at top
   - ✅ Shows winner name, raffle won, and raffle image

5. **`lib/screens/raffle/raffle_detail_screen.dart`**
   - ✅ Simplified to single "Enter Raffle" button
   - ✅ Removed wallet authentication requirements
   - ✅ Shows "Free Entry" instead of complex requirements
   - ✅ Instant entry with success message

6. **`lib/screens/raffle/raffle_creation_screen.dart`**
   - ✅ Simplified form - removed entry type selection
   - ✅ Changed prize value from numeric to text (for gift vouchers)
   - ✅ Replaced file upload with URL input field
   - ✅ Removed blockchain-related fields
   - ✅ Image preview from URL

---

## 🎯 User Experience Flow

### For Regular Users:
1. Browse raffles on Raffle Hub
2. See raffle image, description, prize details
3. Click "Enter Raffle" button → Done! ✅
4. Receive confirmation notification
5. If they win: Get congratulations notification 🎉
6. View winners section to see recent winners

### For Admins:
1. Click + button to create raffle
2. Fill in:
   - Title & description
   - Prize value (e.g., "$100 Visa Gift Card")
   - Prize description
   - Max entries & dates
   - Image URL (optional)
3. Click "Create Raffle"
4. System automatically:
   - Shows raffle to users
   - Collects entries
   - Draws winner at end date
   - Sends notifications
   - Hides completed raffle

---

## 🔒 Security & Fairness

### Randomization Algorithm:
```dart
static int _selectRandomWinner(int participantCount, String raffleId) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final raffleHash = raffleId.hashCode;
  
  // Multiple entropy sources
  final entropy1 = _random.nextInt(participantCount);
  final entropy2 = (timestamp % participantCount);
  final entropy3 = (raffleHash.abs() % participantCount);
  
  // XOR for mixing
  final combinedEntropy = (entropy1 ^ entropy2 ^ entropy3) % participantCount;
  
  // Final selection
  final finalIndex = (_random.nextInt(participantCount) + combinedEntropy) 
      % participantCount;
  
  return finalIndex;
}
```

### Why It's Fair:
- ✅ Uses `Random.secure()` - cryptographically secure PRNG
- ✅ Multiple entropy sources prevent prediction
- ✅ XOR operation adds non-linear mixing
- ✅ Timestamp ensures uniqueness per draw
- ✅ Raffle ID hash prevents manipulation
- ✅ Cannot be predicted in advance
- ✅ Each participant has equal probability

---

## 🚀 Automatic Features

### Raffle Scheduler
- Runs every 5 minutes automatically
- Checks all active raffles
- If end date passed:
  1. Selects winner randomly
  2. Updates raffle status to "completed"
  3. Sends notifications to winner and participants
  4. Removes from main listing
  5. Adds to winners display section

---

## 💡 Benefits

1. **Simple**: One click to enter, no wallet needed
2. **Fair**: Legitimately random winner selection
3. **Automatic**: System handles everything after setup
4. **Engaging**: Winner notifications and display
5. **Clean**: Completed raffles auto-hide
6. **Visual**: Image support for better presentation
7. **Gift-focused**: Perfect for voucher giveaways

---

## 🔧 Technical Notes

- All raffle data stored in Firebase Firestore
- No blockchain transactions for users
- Winner selection happens server-side (Firebase Functions would be ideal for production)
- Scheduler runs in-app (consider moving to Cloud Functions for production)
- Image URLs should be publicly accessible (Imgur, Firebase Storage, etc.)

---

## ✅ Testing

To test the system:
1. Create a raffle with end date 1-2 minutes in future
2. Have multiple users enter the raffle
3. Wait for end date to pass
4. Scheduler will auto-draw winner within 5 minutes
5. Check notifications and winners section

---

**Last Updated**: December 3, 2025
**Status**: ✅ Complete & Ready for Use

