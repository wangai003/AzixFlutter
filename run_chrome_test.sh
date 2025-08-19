#!/bin/bash

# Enhanced Mining System - Chrome Testing Script
# This script sets up and runs the Flutter app in Chrome for testing

echo "🚀 Starting Enhanced Mining System in Chrome..."
echo "=========================================="

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    echo "Visit: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Check if Chrome is available
if ! command -v google-chrome &> /dev/null && ! command -v chrome &> /dev/null; then
    echo "⚠️  Chrome not found in PATH, but Flutter will try to launch it anyway"
fi

echo "📋 Pre-flight checks..."

# Clean and get dependencies
echo "🧹 Cleaning Flutter project..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

# Check for common issues
echo "🔍 Checking project health..."
flutter doctor --brief

echo "🌐 Enabling web support..."
flutter config --enable-web

echo "🔧 Building for web..."
flutter build web --release

echo "🚀 Starting development server..."
echo ""
echo "🎯 The application will open in Chrome at: http://localhost:8080"
echo "📱 You can test the enhanced mining system immediately"
echo "🔐 All security features are enabled and ready for testing"
echo ""
echo "📖 Testing Instructions:"
echo "   1. Sign up or sign in to your account"
echo "   2. Navigate to the Mining tab (first tab)"
echo "   3. Click 'Start Mining' to begin secure mining"
echo "   4. Monitor real-time earnings and security status"
echo "   5. Test pause/resume functionality"
echo "   6. Check security panel for integrity monitoring"
echo ""
echo "⚠️  Note: Press Ctrl+C to stop the development server"
echo ""

# Start the development server
flutter run -d chrome \
    --web-port=8080 \
    --web-hostname=localhost \
    --dart-define=FLUTTER_WEB_AUTO_DETECT=true \
    --web-renderer=html

echo ""
echo "👋 Development server stopped."
echo "💡 To restart, run: ./run_chrome_test.sh"
