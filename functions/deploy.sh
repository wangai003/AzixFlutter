#!/bin/bash

# Cloud Mining Infrastructure Deployment Script
# This script deploys the Firebase Cloud Functions for the cloud mining system

echo "🚀 Starting Cloud Mining Infrastructure Deployment"

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Installing..."
    npm install -g firebase-tools
fi

# Check if user is logged in
if ! firebase projects:list &> /dev/null; then
    echo "❌ Not logged in to Firebase. Please run: firebase login"
    exit 1
fi

# Get project ID from firebase.json or prompt user
PROJECT_ID=$(grep -o '"projectId": "[^"]*"' firebase.json | cut -d'"' -f4)

if [ -z "$PROJECT_ID" ]; then
    echo "Enter your Firebase project ID:"
    read PROJECT_ID
fi

echo "📍 Deploying to project: $PROJECT_ID"

# Set the project
firebase use $PROJECT_ID

# Install dependencies
echo "📦 Installing dependencies..."
cd functions
npm install

# Build the functions
echo "🔨 Building functions..."
npm run build 2>/dev/null || echo "No build script found, skipping build"

# Deploy functions
echo "☁️ Deploying Cloud Functions..."
firebase deploy --only functions

# Update Firestore rules and indexes
echo "📋 Updating Firestore security rules..."
firebase deploy --only firestore:rules

echo "🔗 Updating Firestore indexes..."
firebase deploy --only firestore:indexes

# Run basic health check
echo "🏥 Running health check..."
HEALTH_URL="https://us-central1-$PROJECT_ID.cloudfunctions.net/api/health"
HEALTH_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null $HEALTH_URL)

if [ "$HEALTH_RESPONSE" = "200" ]; then
    echo "✅ Health check passed!"
else
    echo "⚠️ Health check failed with status: $HEALTH_RESPONSE"
fi

echo "🎉 Deployment completed!"
echo ""
echo "📊 Next steps:"
echo "1. Update your Flutter app's API base URL in cloud_mining_service.dart"
echo "2. Replace 'YOUR_PROJECT_ID' with: $PROJECT_ID"
echo "3. Test the mining functionality in your app"
echo "4. Monitor functions logs: firebase functions:log"
echo ""
echo "🔧 Useful commands:"
echo "- View logs: firebase functions:log"
echo "- Test locally: firebase emulators:start"
echo "- Update functions: firebase deploy --only functions"