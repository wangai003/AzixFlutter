@echo off
REM Enhanced Mining System - Chrome Testing Script for Windows
REM This script sets up and runs the Flutter app in Chrome for testing

echo 🚀 Starting Enhanced Mining System in Chrome...
echo ==========================================

REM Check if Flutter is installed
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Flutter is not installed. Please install Flutter first.
    echo Visit: https://flutter.dev/docs/get-started/install
    pause
    exit /b 1
)

echo 📋 Pre-flight checks...

REM Clean and get dependencies
echo 🧹 Cleaning Flutter project...
flutter clean

echo 📦 Getting dependencies...
flutter pub get

REM Check for common issues
echo 🔍 Checking project health...
flutter doctor --brief

echo 🌐 Enabling web support...
flutter config --enable-web

echo 🚀 Starting development server...
echo.
echo 🎯 The application will open in Chrome at: http://localhost:8080
echo 📱 You can test the enhanced mining system immediately
echo 🔐 All security features are enabled and ready for testing
echo.
echo 📖 Testing Instructions:
echo    1. Sign up or sign in to your account
echo    2. Navigate to the Mining tab (first tab)
echo    3. Click 'Start Mining' to begin secure mining
echo    4. Monitor real-time earnings and security status
echo    5. Test pause/resume functionality
echo    6. Check security panel for integrity monitoring
echo.
echo ⚠️  Note: Press Ctrl+C to stop the development server
echo.

REM Start the development server
flutter run -d chrome --web-port=8080 --web-hostname=localhost --dart-define=FLUTTER_WEB_AUTO_DETECT=true

echo.
echo 👋 Development server stopped.
echo 💡 To restart, run: run_chrome_test.bat
pause
