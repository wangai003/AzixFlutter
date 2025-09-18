// 🚀 M-Pesa CORS Proxy Setup for Flutter Web
// Run this with: node setup_cors_proxy.js

const { exec } = require('child_process');
const http = require('http');

console.log('🚀 Setting up M-Pesa CORS Proxy for Flutter Web...\n');

// Check if cors-anywhere is installed
console.log('📦 Checking if cors-anywhere is installed...');
exec('cors-anywhere --version', (error, stdout, stderr) => {
  if (error) {
    console.log('❌ cors-anywhere not found. Installing...');

    // Install cors-anywhere
    exec('npm install -g cors-anywhere', (installError, installStdout, installStderr) => {
      if (installError) {
        console.log('❌ Failed to install cors-anywhere:', installError.message);
        console.log('💡 Try: npm install -g cors-anywhere');
        return;
      }

      console.log('✅ cors-anywhere installed successfully!');
      startProxy();
    });
  } else {
    console.log('✅ cors-anywhere is already installed');
    startProxy();
  }
});

function startProxy() {
  console.log('\n🌐 Starting CORS proxy server...');

  // Start cors-anywhere proxy
  const proxyProcess = exec('cors-anywhere --port 8080', (error, stdout, stderr) => {
    if (error) {
      console.log('❌ Failed to start proxy:', error.message);
      return;
    }
  });

  // Wait a bit for the proxy to start
  setTimeout(() => {
    // Test if proxy is running
    const testRequest = http.get('http://localhost:8080/http://httpbin.org/get', (res) => {
      console.log('✅ CORS Proxy is running successfully!');
      console.log('🔗 Proxy URL: http://localhost:8080');
      console.log('\n📋 Next Steps:');
      console.log('1. ✅ Keep this terminal running');
      console.log('2. 🔄 In your Flutter code, set: _useCorsProxy = true');
      console.log('3. 🚀 Run: flutter run -d chrome');
      console.log('4. 📱 Test M-Pesa with phone: 254708374149');
      console.log('\n🎉 Ready for Flutter Web + M-Pesa testing!');
      console.log('💡 Press Ctrl+C to stop the proxy when done');
    });

    testRequest.on('error', (err) => {
      console.log('❌ Proxy test failed. Make sure port 8080 is available');
      console.log('💡 Try killing other processes on port 8080:');
      console.log('   lsof -ti:8080 | xargs kill -9');
    });
  }, 3000);
}

// Handle process termination
process.on('SIGINT', () => {
  console.log('\n👋 CORS Proxy stopped. Happy coding!');
  process.exit(0);
});

console.log('⏳ Setting up... (this may take a moment)');
console.log('💡 If this takes too long, you can also run: cors-anywhere');