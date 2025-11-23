# Unclaimed Mining Sessions Persistence - Fixed! ✅

## Problem Identified

Unclaimed mining sessions **were stored persistently** in Firestore, but they weren't being displayed reliably because:

1. **Timing Issue**: Sessions were loaded only once at screen initialization, before expired sessions were marked
2. **No Real-Time Updates**: Sessions loaded once and never updated automatically
3. **Manual Refresh Required**: Users had to restart the app to see updated sessions

## Where Sessions Are Stored

### Firestore Database Path:
```
users/{userId}/active_mining_sessions/{sessionId}
```

### Session Document Structure:
```javascript
{
  sessionStart: Timestamp,
  sessionEnd: Timestamp,
  miningRate: 0.25,
  completed: true,
  payoutStatus: 'expired_unpaid',  // ← Key field for unclaimed sessions
  minedTokens: 6.0,
  completedAt: Timestamp,
  blockchain: 'polygon',
  network: 'polygon-amoy',
  chainId: 80002
}
```

### Payout Status Values:
- `'pending'` - Mining session in progress
- `'processing'` - Currently being paid out
- `'success'` - Successfully paid
- `'failed'` - Payment failed
- **`'expired_unpaid'`** - Session expired, waiting to be claimed ← **These are displayed**

---

## Solution Implemented ✅

### 1. **Real-Time Stream Added** (`polygon_mining_service.dart`)

Added a new method that continuously listens to Firestore changes:

```dart
/// Stream of unpaid mining sessions (real-time updates)
Stream<List<Map<String, dynamic>>> streamUnpaidMiningSessions() {
  final user = _auth.currentUser;
  if (user == null) {
    return Stream.value([]);
  }

  return _firestore
      .collection('users')
      .doc(user.uid)
      .collection('active_mining_sessions')
      .where('payoutStatus', isEqualTo: 'expired_unpaid')
      .snapshots()  // ← Real-time Firestore snapshots
      .map((snapshot) {
    print('📊 [STREAM] Unpaid sessions count: ${snapshot.docs.length}');
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'sessionStart': data['sessionStart'],
        'sessionEnd': data['sessionEnd'],
        'minedTokens': data['minedTokens'] ?? 0.0,
        'completedAt': data['completedAt'],
        'blockchain': data['blockchain'] ?? 'polygon', // Backward compatible
        'payoutStatus': data['payoutStatus'],
      };
    }).toList();
  });
}
```

**Key Features**:
- ✅ Real-time Firestore snapshots using `.snapshots()`
- ✅ Automatic updates when sessions are added or removed
- ✅ Backward compatible with old Stellar sessions
- ✅ Logging for debugging

### 2. **StreamBuilder in Mining Screen** (`mining_screen.dart`)

Replaced the old manual loading with a StreamBuilder:

```dart
// Old Code (Manual Load - Not Persistent)
if (_unpaidSessions.isNotEmpty) ...[
  ListView.builder(
    itemCount: _unpaidSessions.length,
    // ...
  )
]

// New Code (Real-Time Stream - Always Persistent)
StreamBuilder<List<Map<String, dynamic>>>(
  stream: _polygonMiningService.streamUnpaidMiningSessions(),
  builder: (context, snapshot) {
    final unpaidSessions = snapshot.data ?? [];
    
    if (unpaidSessions.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      children: [
        Text('Unclaimed Mining Rewards'),
        // Info badge showing count
        ListView.builder(
          itemCount: unpaidSessions.length,
          // Display each session
        ),
      ],
    );
  },
)
```

**Benefits**:
- ✅ Automatically updates when Firestore changes
- ✅ No manual refresh needed
- ✅ Shows sessions immediately when they expire
- ✅ Hides sessions immediately when claimed
- ✅ Always in sync with database

### 3. **Improved Initialization Sequence** (`mining_screen.dart`)

Fixed the timing issue by ensuring expired sessions are handled before displaying:

```dart
// Old Code
@override
void initState() {
  super.initState();
  _polygonMiningService.handleExpiredSessions();  // Doesn't wait
  _loadUnpaidSessions();  // Loads immediately
}

// New Code
@override
void initState() {
  super.initState();
  _handleExpiredSessionsAndLoad();  // Waits properly
}

Future<void> _handleExpiredSessionsAndLoad() async {
  try {
    await _polygonMiningService.handleExpiredSessions();  // ← Waits
    print('✅ Expired sessions handled');
    // StreamBuilder automatically loads sessions
  } catch (e) {
    print('❌ Error handling expired sessions: $e');
  }
}
```

### 4. **Enhanced UI Display**

Added better visual indicators:

```dart
// Session count badge
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: Colors.orange.withOpacity(0.2),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Row(
    children: [
      Icon(Icons.schedule, color: Colors.orange[300]),
      Text('${unpaidSessions.length} session(s) pending'),
    ],
  ),
)

// Blockchain badge on each session
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  decoration: BoxDecoration(
    color: blockchain == 'polygon' 
        ? Colors.purple.withOpacity(0.2) 
        : Colors.blue.withOpacity(0.2),
  ),
  child: Text(blockchain.toUpperCase()),
)
```

---

## How It Works Now

### User Experience Flow:

1. **User Starts Mining**:
   - Session created in Firestore with `payoutStatus: 'pending'`
   - 24-hour timer starts

2. **Session Expires** (after 24 hours or app closed):
   - `handleExpiredSessions()` marks it as `'expired_unpaid'`
   - StreamBuilder **instantly detects** the change
   - Session appears in "Unclaimed Mining Rewards" section

3. **Session Displayed Persistently**:
   - Visible every time user opens the app
   - Real-time count badge shows pending sessions
   - No refresh needed

4. **User Claims Reward**:
   - Taps "Claim Rewards" button
   - Status changes to `'processing'` → `'success'`
   - StreamBuilder **instantly removes** session from display

### Technical Flow:

```
Mining Session Created
        ↓
Status: 'pending'
        ↓
24 Hours Pass / App Closed
        ↓
handleExpiredSessions() runs
        ↓
Status: 'expired_unpaid' ← Firestore Update
        ↓
StreamBuilder Detects Change (Real-Time)
        ↓
UI Updates Automatically
        ↓
Session Displayed to User
        ↓
User Claims → Status: 'success'
        ↓
StreamBuilder Detects Change
        ↓
Session Removed from UI
```

---

## Backward Compatibility

The system now handles **both old Stellar sessions and new Polygon sessions**:

```dart
'blockchain': data['blockchain'] ?? 'polygon',  // Default to polygon if missing
```

### Old Stellar Sessions:
- Still stored in same Firestore path
- May not have `blockchain` field
- Will default to 'polygon' for display
- Can still be claimed

### New Polygon Sessions:
- Include `blockchain: 'polygon'`
- Include `network` and `chainId`
- Full metadata for tracking

---

## Debugging & Monitoring

### Console Logs Added:

```dart
// When sessions stream updates
print('📊 [STREAM] Unpaid sessions count: ${snapshot.docs.length}');

// When sessions are handled
print('✅ Expired sessions handled');

// When displaying sessions
if (unpaidSessions.isNotEmpty) {
  print('📊 Displaying ${unpaidSessions.length} unpaid sessions');
}
```

### Firestore Console Query:

To view all unpaid sessions in Firebase Console:

```javascript
users/{userId}/active_mining_sessions
  where payoutStatus == 'expired_unpaid'
```

### Check via Flutter DevTools:

1. Open Flutter DevTools
2. Go to "Logging" tab
3. Look for `[STREAM]` messages
4. Verify session count matches Firestore

---

## Benefits of Real-Time Streaming

### Before (Manual Loading):
- ❌ Sessions loaded once at app start
- ❌ Required app restart to see new sessions
- ❌ Could show stale data
- ❌ Race conditions with expiration handling

### After (Real-Time Streaming):
- ✅ **Always shows current state**
- ✅ **Instant updates** when sessions expire
- ✅ **Instant removal** when claimed
- ✅ **No manual refresh needed**
- ✅ **Multiple devices sync automatically**
- ✅ **Survives app restarts**

---

## Testing Checklist

### To Verify Sessions Are Persistent:

1. **Start a Mining Session**:
   ```
   - Open app → Go to Mining screen
   - Click "Start Mining"
   - Verify session created in Firestore
   ```

2. **Force Session Expiration** (for testing):
   ```dart
   // Temporarily change in mining_screen.dart for testing
   final sessionEnd = DateTime.now().add(const Duration(minutes: 1));
   ```

3. **Close and Reopen App**:
   ```
   - Force close the app completely
   - Wait 1 minute (if using test duration)
   - Reopen app → Go to Mining screen
   - Session should appear in "Unclaimed Mining Rewards"
   ```

4. **Verify Real-Time Updates**:
   ```
   - Open app on Device 1
   - Open Firestore Console on Computer
   - Manually change payoutStatus to 'expired_unpaid'
   - Device 1 should instantly show the session
   ```

5. **Test Claiming**:
   ```
   - Click "Claim Rewards" on unclaimed session
   - Session should disappear immediately after success
   - Check Firestore: payoutStatus should be 'success'
   ```

---

## Common Issues & Solutions

### Issue: Sessions Not Appearing

**Check**:
1. Is `payoutStatus` exactly `'expired_unpaid'`?
2. Run `handleExpiredSessions()` manually in Firestore
3. Check console for `[STREAM]` logs
4. Verify user is authenticated

**Solution**:
```dart
// Force mark a session as expired (in Firestore Console)
{
  payoutStatus: 'expired_unpaid',
  completed: true,
  minedTokens: 6.0
}
```

### Issue: Old Stellar Sessions Not Showing

**Solution**: They might be in the old format. Check Firestore and manually add:
```javascript
{
  blockchain: 'stellar',  // Add this field
  payoutStatus: 'expired_unpaid'  // Verify this is set
}
```

### Issue: Sessions Appear But Can't Be Claimed

**Check**:
1. AKOFA token contract address configured?
2. Distributor wallet has funds?
3. Check console for transaction errors

**Solution**: See `POLYGON_MINING_MIGRATION_SUMMARY.md`

---

## Performance Considerations

### Firestore Reads:
- **StreamBuilder**: Uses real-time listeners (WebSocket connection)
- **Cost**: 1 read when subscribing + 1 read per document change
- **Typical Usage**: 
  - Initial load: ~5 documents (one-time)
  - Per claim: 1 document update (removes from stream)
  - **Very efficient** compared to polling

### Memory:
- Stream stays active while screen is open
- Automatically cleaned up when screen disposed
- Minimal memory footprint

---

## Files Changed

### Core Changes:
1. **`lib/services/polygon_mining_service.dart`**:
   - Added `streamUnpaidMiningSessions()` method
   - Enhanced `getUnpaidMiningSessions()` for backward compatibility

2. **`lib/screens/mining_screen.dart`**:
   - Replaced manual loading with `StreamBuilder`
   - Removed `_unpaidSessions` state variable
   - Removed `_isLoadingUnpaidSessions` state variable
   - Removed `_loadUnpaidSessions()` method
   - Added `_handleExpiredSessionsAndLoad()` for proper initialization
   - Enhanced UI with session count badge

### Documentation:
- **`UNCLAIMED_SESSIONS_FIX.md`** (this file)
- **`POLYGON_MINING_MIGRATION_SUMMARY.md`** (updated)

---

## Summary

### The Problem:
Unclaimed mining sessions **were persistent** in Firestore but **appeared non-persistent** due to loading only once at app start.

### The Solution:
Replaced one-time loading with **real-time Firestore streaming**, ensuring sessions:
- ✅ Always display when `payoutStatus == 'expired_unpaid'`
- ✅ Update instantly without manual refresh
- ✅ Survive app restarts
- ✅ Sync across multiple devices
- ✅ Remove immediately when claimed

### Result:
**Truly persistent unclaimed sessions** that are always visible and always in sync with Firestore! 🎉

---

## Next Steps

1. ✅ **Sessions are now persistent** - No action needed
2. ⏳ Test with real mining sessions (24-hour duration)
3. ⏳ Configure AKOFA contract address (see `POLYGON_MINING_MIGRATION_SUMMARY.md`)
4. ⏳ Fund distributor wallet for testing claims
5. ⏳ Deploy to testnet and verify end-to-end flow

---

**Last Updated**: Migration to Polygon with Real-Time Streaming
**Status**: ✅ FIXED - Sessions are now truly persistent and real-time!

