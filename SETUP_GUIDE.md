# AquaBalance - Water Tracking App

## Setup Instructions

### 1. Asset Images

You need to add two image files to the `assets/images/` directory:

#### Directory: `assets/images/`

**Files to add:**

1. **logo.png** (Recommended: 200x200 pixels)
   - Path: `assets/images/logo.png`
   - This is the AquaBalance logo displayed at the top of login and register pages
   - Should be a square image with transparent background
   - Recommended size: 200x200 px or larger

2. **google_logo.png** (Recommended: 24x24 pixels)
   - Path: `assets/images/google_logo.png`
   - This is the Google logo for the sign-in buttons
   - Recommended size: 24x24 px

#### How to add images:

1. Create the directories if they don't exist:

   ```
   assets/
   └── images/
       ├── logo.png
       └── google_logo.png
   ```

2. Place your image files in these locations

3. The `pubspec.yaml` is already configured to load these assets

### 2. Firebase Setup

#### For Android:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project
3. Add Android app
4. Download `google-services.json`
5. Place it in `android/app/` directory

#### For iOS:

1. Add iOS app to Firebase project
2. Download `GoogleService-Info.plist`
3. Open `ios/Runner.xcworkspace` in Xcode
4. Add the plist file to the project

#### For Google Sign-In:

1. Enable Google Sign-In in Firebase Console (Authentication → Sign-in method)
2. Configure OAuth consent screen
3. Add your app's SHA-1 fingerprint in Firebase settings

### 3. Running the App

```bash
# Install dependencies
flutter pub get

# Run on Android emulator
flutter run

# Run on iOS simulator
flutter run -d ios

# Run on desktop (Windows/macOS/Linux)
flutter run -d windows
# or
flutter run -d macos
# or
flutter run -d linux
```

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── screens/
│   ├── login_page.dart         # Login UI with email/Google signin
│   └── register_page.dart      # Registration UI with email/Google signup
└── services/
    └── auth_service.dart       # Firebase authentication service

assets/
└── images/
    ├── logo.png                # App logo (add this)
    └── google_logo.png         # Google sign-in logo (add this)
```

## Features Implemented

✅ **Login Page**

- Email and password login
- Google Sign-In button
- Error handling
- Link to register page

✅ **Register Page**

- Email registration with name, age, email, password
- Email verification before account creation
- Privacy policy acceptance
- Google Sign-Up button
- Password confirmation
- Input validation

✅ **Authentication Service**

- Firebase email/password authentication
- Google Sign-In integration
- Email verification flow
- User profile management

✅ **Privacy Policy**

- Embedded privacy policy dialog in registration
- Covers data collection, usage, security, and user rights

## Next Steps

1. Add your image files to `assets/images/`
2. Configure Firebase project and add keys
3. Run `flutter run` to test the app
4. Build main dashboard after auth
5. Add water tracking functionality
