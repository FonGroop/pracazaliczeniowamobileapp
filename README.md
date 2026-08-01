# City Companion

Flutter application for discovering nearby places, saving them, creating
map-based ideas and planning a day in the city.

## Requirements

- Flutter SDK compatible with Dart `^3.12.0`
- A Firebase project with Authentication, Cloud Firestore and Cloud Storage
- FlutterFire CLI (`dart pub global activate flutterfire_cli`)

## Run locally

1. Clone the repository and open its directory.
2. Create a local environment file:

   ```bash
   cp .env.example .env
   ```

   Set `PLACES_API_URL` in `.env`. The supplied template points to Wikipedia
   GeoSearch and substitutes `{language}` with `pl` or `en` at runtime.

3. Install dependencies and generate code:

   ```bash
   flutter pub get
   dart run build_runner build
   flutter gen-l10n
   ```

4. Connect Firebase. `flutterfire configure` creates the local Firebase
   options and platform files that are intentionally excluded from Git:

   ```bash
   flutterfire configure
   ```

   The generated `firebase.json` is different: it contains only shared
   project/app identifiers, no API key or credentials. Keep it versioned when
   everyone working on the repository uses the same Firebase project.

5. Run the application on a selected device, for example macOS:

   ```bash
   flutter run -d macos
   ```

   Use `flutter devices` to list available targets.

## Firebase setup

Enable these services in Firebase Console:

- **Authentication** → enable the **Anonymous** sign-in provider.
- **Cloud Firestore** → create a database.
- **Cloud Storage** → create the default bucket.

Apply these Cloud Storage rules. They permit a signed-in user to access only
their own idea attachments:

```text
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /city_notes/{userId}/{noteId}/{fileName} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

Apply these Firestore rules for ideas:

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /city_notes/{noteId} {
      allow create: if request.auth != null
        && request.resource.data.ownerId == request.auth.uid;
      allow read, update, delete: if request.auth != null
        && resource.data.ownerId == request.auth.uid;
    }
  }
}
```

## External places API

The Discover screen and map share one Riverpod discovery area. On first launch,
GPS is enabled and the app requests places near the user's location. After the
user stops moving or zooming the map, the app derives a center and search radius
from the visible viewport, waits briefly to avoid excessive requests, and
replaces the previous recommendations on both screens.

DIO sends the center and radius to Wikipedia GeoSearch. Freezed and
json_serializable decode the response before the repository maps it to app
models. Polish mode queries Polish Wikipedia and English mode queries English
Wikipedia. GPS can be disabled in Settings; Warsaw is then used as the starting
point. If Wikipedia is unavailable while viewing Warsaw, only built-in places
inside the current search radius are used as an offline fallback.

## Generated and private files

The repository does not contain `.env`, Firebase credentials or generated
platform configuration, generated Dart files, build products or IDE cache.
Regenerate them with the commands above after cloning. When you change a
Freezed model or Envied configuration, run:

```bash
dart run build_runner build
```

When you change an ARB localization file, run:

```bash
flutter gen-l10n
```

## Daily Git workflow

1. Make a focused change in `lib/`, `test/`, `assets/`, documentation or
   project configuration.
2. Generate and verify the project locally:

   ```bash
   dart run build_runner build
   flutter gen-l10n
   flutter test
   flutter analyze
   ```

3. Inspect exactly what will be committed:

   ```bash
   git status
   git diff
   ```

4. Stage explicit source files rather than using `git add .` blindly:

   ```bash
   git add lib/ test/ assets/ README.md pubspec.yaml pubspec.lock .gitignore
   ```

   Add `firebase.json` only when the shared Firebase project configuration
   changes. Do not add `.env`, `firebase_options.dart`, `google-services.json`,
   `GoogleService-Info.plist`, build folders or generated Dart files.

5. Review staged files, commit and push:

   ```bash
   git diff --cached --name-only
   git commit -m "Describe the change"
   git push
   ```

If an unwanted file appears in `git status`, check why before staging it:

```bash
git check-ignore -v path/to/file
```

## macOS location troubleshooting

The macOS runner already contains the required location entitlement and usage
description. If centering is denied, use the app's **Center on my location**
button and choose **Open settings**. In macOS, open **System Settings → Privacy
& Security → Location Services**, enable Location Services and allow
`pracazaliczeniowamobileapp`, then return to the app and press the centering
button again. Stop and rebuild the app if it does not yet appear in the system
list.
