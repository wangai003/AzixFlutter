@echo off
echo 🔧 Deploying Firebase indexes for enhanced mining system...
echo.

REM Check if Firebase CLI is installed
where firebase >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Firebase CLI is not installed.
    echo Please install it with: npm install -g firebase-tools
    echo Then run: firebase login
    pause
    exit /b 1
)

echo 📋 Deploying Firestore indexes...
firebase deploy --only firestore:indexes

echo.
echo 🔐 Deploying Firestore security rules...
firebase deploy --only firestore:rules

echo.
echo ✅ Firebase configuration deployed successfully!
echo 🎯 Your enhanced mining system should now work without index errors.
echo.
echo 💡 You can now restart your app with: run_chrome_test.bat
pause
