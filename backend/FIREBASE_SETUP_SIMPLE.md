# Simple Firebase Backend Setup (3 Steps!)

## Super Simple Method - Just 3 Steps!

### Step 1: Install Package
```bash
cd backend
npm install firebase-admin
```

### Step 2: Download Service Account File
1. Go to: https://console.firebase.google.com/
2. Select your project: **azix-7ffe4**
3. Click ⚙️ (Settings) → **Project settings**
4. Click **Service accounts** tab
5. Click **Generate new private key**
6. Click **Generate key** (downloads a JSON file)

### Step 3: Place File in Backend Folder
1. Rename the downloaded file to: `firebase-service-account.json`
2. Move it to: `backend/firebase-service-account.json`
3. **That's it!** 🎉

### Done!
Start your backend:
```bash
npm start
```

You should see: `✅ Firebase Admin initialized for store payments`

---

## Security Note
- **Never commit** `firebase-service-account.json` to Git
- It's already in `.gitignore` (if not, add it)
- This file gives full access to your Firestore database

---

## That's It!
The backend will automatically:
- ✅ Detect the file
- ✅ Load Firebase credentials
- ✅ Connect to Firestore
- ✅ Store payment transactions

No environment variables needed! No complex configuration! Just drop the file and go! 🚀

