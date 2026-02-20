# Google Sign-In (Android) configuration

This project requires the Google "Web client ID" to be set for Google Sign-In on Android.

Steps:

- Open Google Cloud Console -> APIs & Services -> Credentials.
- Create an OAuth 2.0 Client ID of type **Web application** (if you don't have one).
- Copy the **Client ID** (looks like `...apps.googleusercontent.com`).
- In this repo, open `lib/services/auth_service.dart` and replace the
  `kGoogleServerClientId` value with that Client ID.

Notes:

- Ensure your Android app's package name and SHA-1 are registered in the
  Firebase project if you use Firebase Authentication.
- After updating the value, rebuild the app (`flutter clean` then `flutter run`).
