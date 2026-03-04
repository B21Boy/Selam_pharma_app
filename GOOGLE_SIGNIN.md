# Google Sign-In configuration

The Android implementation of Google Sign-In requires a **Google Web client
ID** (an OAuth 2.0 client of type "Web application").

The app includes a built‑in default Web client ID (the one associated
with this repo's Firebase project) so Google sign‑in works out of the box.
If you need to override it—e.g. for testing multiple Firebase projects or
rotating credentials—you can supply the ID in one of the following ways:

1. **.env file** (using `flutter_dotenv`)
   ```text
   GOOGLE_SERVER_CLIENT_ID=12345-abcde.apps.googleusercontent.com
   ```
2. **Dart define at build time**
   ```bash
   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<your id>
   flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=<your id>
   ```
3. **Firebase Remote Config** (key `google_server_client_id`)
   - Add the key/value pair in the Firebase console under Remote Config.
   - The app will fetch/activate config when attempting a Google sign‑in.
   - This lets you change the ID without rebuilding the application.

Steps to obtain the ID:

- Open Google Cloud Console → APIs & Services → Credentials.
- Create an OAuth 2.0 Client ID of type **Web application** if you don't
  already have one.
- Copy the **Client ID** (looks like `...apps.googleusercontent.com`).

## Updating the app

- Place the value in one of the locations described above.
- If you use the `.env` approach, make sure the file is loaded early in
  `main()` ([see `flutter_dotenv` docs](https://pub.dev/packages/flutter_dotenv)).
- Rebuild or restart the app. A rebuild is required when using
  `.env`/`--dart-define`, but not when using Remote Config.

> ⚠️ The old instructions about directly editing
> `kGoogleServerClientId` in `auth_service.dart` are no longer needed.
> The code now resolves the value dynamically.

### Credentials bundled with this project

For reference, the Firebase project that backs the example app
already contains these automatically‑generated OAuth client IDs:

| Platform | Package / ID                   | Client ID (Web‑type)                                                     |
| -------- | ------------------------------ | ------------------------------------------------------------------------ |
| Android  | `com.deksi.pharmacy`           | 336526161177-fhjclo5oearsg2vppt1gqf3iulbr8oep.apps.googleusercontent.com |
| iOS      | `com.deksi.pharmacyios`        | 336526161177-4oflh2tc03ujrlr28j8g5rpsvq5rgttn.apps.googleusercontent.com |
| Web      | (not used directly at runtime) | 336526161177-o7q6340g3dhv6qa59hrbad04uh5h3mod.apps.googleusercontent.com |

The **Web client ID** is the only value used by `google_sign_in` on
Android/iOS; the Android and iOS IDs are handled internally by the
Firebase SDK and are configured via `google-services.json` /
`GoogleService-Info.plist`.

Feel free to override the web ID using one of the methods above, but the
built‑in default already matches the value listed here.
