# Chrome Testing Guide for Enhanced Mining System

## Quick Start Commands

### 1. Run the Application
```bash
flutter run -d chrome --web-port=8080
```

### 2. Alternative with Hot Reload
```bash
flutter run -d chrome --web-port=8080 --web-hostname=localhost
```

## Testing Flow for Non-Technical Users

### Step 1: Open the Application
1. Run the command above
2. Chrome will automatically open to `http://localhost:8080`
3. Wait for the app to load completely

### Step 2: User Authentication
1. **Sign Up** (if new user):
   - Click "Sign Up" 
   - Enter email and password
   - Complete email verification
   - Fill in user registration form

2. **Sign In** (if existing user):
   - Enter your email and password
   - Click "Sign In"

### Step 3: Navigate to Mining
1. Once logged in, you'll see the main navigation
2. The **first tab (Home)** is the enhanced mining screen
3. You should see:
   - AZIX Mining header with gold accent
   - Security status icon in the top right
   - Large mining status card showing "INACTIVE"
   - "Start Mining" button
   - Wallet info button

### Step 4: Start Mining (First Time)
1. **Create Wallet** (if needed):
   - Click the wallet icon in the top right
   - If no wallet exists, you'll be prompted to create one
   - Follow the wallet creation process

2. **Start Your First Mining Session**:
   - Click the blue "Start Mining" button
   - The system will:
     - Validate your account automatically
     - Create a secure mining session
     - Begin proof-of-work generation
   - You should see:
     - Status change to "MINING" with gold color
     - Animated mining icon
     - Real-time earnings counter
     - Progress bar for the 24-hour session

### Step 5: Monitor Your Mining
1. **Real-time Updates**:
   - Earnings update every second
   - Progress bar shows session completion
   - Time remaining displayed

2. **Security Features**:
   - Click the security icon to see status
   - View integrity checks and validation
   - Monitor any security alerts

3. **Pause/Resume**:
   - Use the pause button to temporarily stop
   - Resume mining anytime during the session
   - Session automatically saves progress

### Step 6: View Mining Details
1. **Session Information**:
   - Scroll down to see detailed session info
   - View session ID, start time, and end time
   - Check proof submissions and validation

2. **Quick Actions**:
   - Access transaction history
   - View wallet information
   - Check security overview

### Step 7: End Session (Optional)
1. Sessions automatically end after 24 hours
2. Rewards are automatically credited to your wallet
3. You can view the completion notification
4. Start a new session the next day

## Expected Behavior

### ✅ What You Should See
- **Smooth Loading**: App loads within 10 seconds
- **Responsive Design**: Works well in Chrome window
- **Real-time Updates**: Earnings counter updates every second
- **Security Monitoring**: Live security status indicators
- **Auto-save**: Session progress saves automatically
- **Clean UI**: Modern dark theme with gold accents

### ⚠️ Normal Limitations
- **Daily Limit**: Only 1 mining session per day per device
- **Rate Limiting**: Protection against excessive attempts
- **Session Duration**: Exactly 24 hours maximum
- **Device Tracking**: Maximum 3 devices per account

### 🔍 Testing Different Scenarios

#### Scenario 1: First-Time User
1. Create account
2. Verify email
3. Complete registration
4. Create wallet
5. Start first mining session

#### Scenario 2: Returning User
1. Sign in
2. Check for existing session
3. Resume or start new session
4. View mining history

#### Scenario 3: Rate Limiting Test
1. Try to start multiple sessions rapidly
2. Should be blocked after 3 attempts per hour
3. View security alerts

#### Scenario 4: Security Features
1. Toggle security panel
2. Monitor proof submissions
3. Check session integrity
4. View security metrics

## Troubleshooting

### App Won't Load
- Clear browser cache and cookies
- Try incognito/private mode
- Check console for errors (F12)
- Ensure stable internet connection

### Can't Start Mining
- Check if you have an active session
- Verify wallet is created
- Look for rate limit messages
- Check security alerts panel

### Slow Performance
- Close other browser tabs
- Check system resources
- Try smaller browser window
- Clear browser data

### Firebase Connection Issues
- Check internet connection
- Verify Firebase project is active
- Look for CORS errors in console
- Try refreshing the page

## Development Console Access

### Useful Console Commands (F12)
```javascript
// Check current user
firebase.auth().currentUser

// View local storage
localStorage

// Check network requests
// Go to Network tab and monitor Firebase calls
```

### Useful Browser Settings
1. **Disable Cache**: 
   - F12 → Network → Disable cache (checked)
2. **Responsive Testing**: 
   - F12 → Toggle device toolbar
3. **Performance Monitoring**: 
   - F12 → Performance tab

## Expected Mining Flow Timeline

### Immediate (0-5 seconds)
- App loads and shows login screen
- Firebase authentication initializes

### Short Term (5-30 seconds)
- User authentication completes
- Mining services initialize
- Wallet status loads
- Security validation runs

### Medium Term (30 seconds - 5 minutes)
- Mining session starts
- First proof submission
- Real-time updates begin
- Security monitoring active

### Long Term (5+ minutes)
- Continuous proof generation
- Periodic server validation
- Progress tracking
- Earnings accumulation

## Performance Benchmarks

### Loading Times
- **Initial Load**: < 10 seconds
- **Authentication**: < 5 seconds
- **Mining Start**: < 3 seconds
- **Proof Generation**: < 100ms

### Resource Usage
- **Memory**: < 100MB typical
- **CPU**: < 5% during mining
- **Network**: Minimal (periodic validation)
- **Storage**: < 10MB local data

## Success Metrics

### ✅ Test Passed If:
1. App loads smoothly in Chrome
2. User can sign up/sign in
3. Mining starts without errors
4. Earnings update in real-time
5. Security features work properly
6. Session persists across page reloads
7. No critical errors in console

### 🔍 Areas to Focus Testing:
1. **Authentication Flow**: Sign up, sign in, email verification
2. **Mining Process**: Start, pause, resume, automatic end
3. **Security Features**: Rate limiting, device tracking, proof validation
4. **User Experience**: Responsive design, clear messaging, intuitive navigation
5. **Error Handling**: Network issues, invalid input, system limits

This testing approach ensures the enhanced mining system works seamlessly for end users without requiring technical knowledge.
