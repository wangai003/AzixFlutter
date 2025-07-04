# AZIX Flutter Application Information

## Summary
AZIX is a Flutter mobile application that integrates with Firebase and Stellar blockchain. The app provides wallet functionality, authentication, chat services, and cryptocurrency features including QR scanning, transactions, and wallet management.

## Structure
- **lib/**: Core application code organized by feature
  - **models/**: Data models for app entities
  - **providers/**: State management using Provider pattern
  - **screens/**: UI screens and pages
  - **services/**: Business logic and API integrations
  - **widgets/**: Reusable UI components
  - **utils/**: Utility functions and helpers
- **assets/**: Static resources (images, animations)
- **android/**, **ios/**, **web/**, **macos/**, **linux/**, **windows/**: Platform-specific code

## Language & Runtime
**Language**: Dart
**Flutter SDK**: ^3.8.1
**Build System**: Flutter build system
**Package Manager**: pub (Flutter/Dart package manager)

## Dependencies
**Main Dependencies**:
- **State Management**: provider (^6.1.1)
- **Firebase**: firebase_core (^2.25.4), firebase_auth (^4.17.4), cloud_firestore (^4.15.4)
- **Authentication**: google_sign_in (^6.2.1), flutter_secure_storage (^9.0.0), local_auth (^2.1.6)
- **Blockchain**: stellar_flutter_sdk (^1.6.1), encrypt (^5.0.1), crypto (^3.0.3)
- **UI/UX**: flutter_animate (^4.5.0), lottie (^3.0.0), google_fonts (^6.1.0), flutter_svg (^2.0.9)
- **QR Code**: qr_flutter (^4.1.0), qr_code_scanner (^1.0.1)
- **Payments**: flutter_stripe (^11.5.0)

**Development Dependencies**:
- flutter_test
- flutter_lints (^5.0.0)

## Build & Installation
```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Build release APK for Android
flutter build apk --release

# Build release IPA for iOS
flutter build ios --release

# Build for web
flutter build web --release
```

## Testing
**Framework**: flutter_test
**Test Location**: test/
**Naming Convention**: *_test.dart
**Run Command**:
```bash
flutter test
```

## Platform Support
The application is configured for multiple platforms:
- **Mobile**: Android, iOS
- **Desktop**: Windows, macOS, Linux
- **Web**: Browser-based version

## Firebase Integration
The application uses Firebase for:
- Authentication (email/password, Google Sign-in)
- Cloud Firestore for data storage
- Cloud Functions for server-side logic
- Firebase Storage for file storage

## Stellar Blockchain Integration
The app integrates with Stellar blockchain for:
- Wallet creation and management
- Cryptocurrency transactions
- Secure key storage with encryption# AZIX Flutter Application Information

## Summary
AZIX is a Flutter mobile application that integrates with Firebase and Stellar blockchain. The app provides wallet functionality, authentication, chat services, and cryptocurrency features including QR scanning, transactions, and wallet management.

## Structure
- **lib/**: Core application code organized by feature
  - **models/**: Data models for app entities
  - **providers/**: State management using Provider pattern
  - **screens/**: UI screens and pages
  - **services/**: Business logic and API integrations
  - **widgets/**: Reusable UI components
  - **utils/**: Utility functions and helpers
- **assets/**: Static resources (images, animations)
- **android/**, **ios/**, **web/**, **macos/**, **linux/**, **windows/**: Platform-specific code

## Language & Runtime
**Language**: Dart
**Flutter SDK**: ^3.8.1
**Build System**: Flutter build system
**Package Manager**: pub (Flutter/Dart package manager)

## Dependencies
**Main Dependencies**:
- **State Management**: provider (^6.1.1)
- **Firebase**: firebase_core (^2.25.4), firebase_auth (^4.17.4), cloud_firestore (^4.15.4)
- **Authentication**: google_sign_in (^6.2.1), flutter_secure_storage (^9.0.0), local_auth (^2.1.6)
- **Blockchain**: stellar_flutter_sdk (^1.6.1), encrypt (^5.0.1), crypto (^3.0.3)
- **UI/UX**: flutter_animate (^4.5.0), lottie (^3.0.0), google_fonts (^6.1.0), flutter_svg (^2.0.9)
- **QR Code**: qr_flutter (^4.1.0), qr_code_scanner (^1.0.1)
- **Payments**: flutter_stripe (^11.5.0)

**Development Dependencies**:
- flutter_test
- flutter_lints (^5.0.0)

## Build & Installation
```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Build release APK for Android
flutter build apk --release

# Build release IPA for iOS
flutter build ios --release

# Build for web
flutter build web --release
```

## Testing
**Framework**: flutter_test
**Test Location**: test/
**Naming Convention**: *_test.dart
**Run Command**:
```bash
flutter test
```

## Platform Support
The application is configured for multiple platforms:
- **Mobile**: Android, iOS
- **Desktop**: Windows, macOS, Linux
- **Web**: Browser-based version

## Firebase Integration
The application uses Firebase for:
- Authentication (email/password, Google Sign-in)
- Cloud Firestore for data storage
- Cloud Functions for server-side logic
- Firebase Storage for file storage

## Stellar Blockchain Integration
The app integrates with Stellar blockchain for:
- Wallet creation and management
- Cryptocurrency transactions
- Secure key storage with encryption