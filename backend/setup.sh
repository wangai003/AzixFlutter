#!/bin/bash

# AzixFlutter Backend Setup Script
# Run this to quickly setup the gasless backend

echo "🚀 AzixFlutter Gasless Backend Setup"
echo "===================================="
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found!"
    echo "📥 Please install Node.js from: https://nodejs.org/"
    exit 1
fi

NODE_VERSION=$(node -v)
echo "✅ Node.js installed: $NODE_VERSION"
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
npm install

if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi

echo "✅ Dependencies installed"
echo ""

# Check for .env file
if [ ! -f .env ]; then
    echo "⚠️  .env file not found"
    echo "📝 Creating .env from template..."
    cp env.template .env
    echo ""
    echo "⚙️  Please edit .env file and add your configuration:"
    echo "   - BICONOMY_BUNDLER_URL (from dashboard)"
    echo "   - BICONOMY_PAYMASTER_URL (from dashboard)"
    echo "   - SERVER_PRIVATE_KEY (your backend wallet)"
    echo "   - Firebase credentials"
    echo ""
    echo "Then run: npm run dev"
else
    echo "✅ .env file found"
    echo ""
    echo "🎯 Starting development server..."
    npm run dev
fi

