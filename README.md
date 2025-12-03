# Flutter Chat App

This repository contains a simple 1-to-1 chat application built with Flutter
and Firebase. It demonstrates the following core concepts required for a
Mobile Computing course submission:

- Firebase Authentication (email/password)
- Cloud Firestore (chat metadata / user profiles)
- Firebase Realtime Database (real-time messages)

This README documents project layout, setup steps, developer notes, and
examples for running and extending the app.

**Status:** Android-focused; Firebase project configuration is expected to
already exist. The repository includes `firebase_options.dart` and package
dependencies for `firebase_core`, `firebase_auth`, `cloud_firestore`, and
`firebase_database`.

**Quick links**
- Project root: `lib/`
- Main entry: `lib/main.dart`
- Models: `lib/models/`
- Services: `lib/services/`
- Screens: `lib/screens/`

--------------------------------------------------------------------------------

## Table of Contents

- Project overview
- Prerequisites
- Setup & Run (Windows PowerShell)
- Project structure and key files
- Data models
- Services (ChatService)
- Authentication & navigation flow
- Firebase rules examples (Realtime DB & Firestore)
- Testing, analysis & formatting
- Troubleshooting
- Next steps and extension ideas

--------------------------------------------------------------------------------

## Project overview

This app is intended as a teaching/demo project for real-time chat using
Firebase. The core design separates concerns:

- UI sits under `lib/screens/`
- Domain models (pure data objects) live in `lib/models/`
- Platform services (Realtime DB / Firestore / Auth wrappers) live in
	`lib/services/`

The Realtime Database is used for message streaming and low-latency updates;
Firestore is used for persistent user profiles and chat metadata (e.g. last
message, participants). Authentication uses Firebase Authentication with
email/password.

--------------------------------------------------------------------------------

## Prerequisites

- Flutter (stable) installed. To check:

```powershell
flutter --version
```

- An Android device or emulator available to run the app.
- A Firebase project already created and configured for Android. The
	generated `firebase_options.dart` file must exist at `lib/firebase_options.dart`.
- Working internet connection for package fetch and Firebase operations.

If you need to initialise Firebase for the project, run the FlutterFire
CLI locally (not required if `firebase_options.dart` is already present):

```powershell
dart pub global activate flutterfire_cli
flutterfire configure
```

--------------------------------------------------------------------------------

## Setup & Run (Windows PowerShell)

1. Fetch packages

```powershell
flutter pub get
```

2. Analyze and format

```powershell
flutter analyze
flutter format .
```

3. Run the app on an attached Android device or emulator

```powershell
flutter run -d <device-id>
```

Replace `<device-id>` with the id from `flutter devices`, or omit `-d` to use
the default device.

--------------------------------------------------------------------------------

## Project structure (important files)

- `lib/main.dart` — App entry, Firebase initialization, `AuthGate`, basic
	login/register screens and routing.
- `lib/models/` — Immutable data models:
	- `user_model.dart` — `UserModel` (uid, username, email)
	- `chat_model.dart` — `ChatModel` (chat id, participants, lastMessage)
	- `message_model.dart` — `MessageModel` (message id, chatId, senderId, text, timestamp)
- `lib/services/` — Application services:
	- `chat_service.dart` — Realtime Database wrapper (sendMessage, messagesStream)
	- `user_service.dart` — Firestore user profile helper
	- other services (placeholders) may be present for metadata and messaging
- `lib/screens/` — Minimal UI screens
	- `chat_list_screen.dart` — Lists chats and user search
	- `chat_screen.dart` — Chat UI using `ChatService` streams

--------------------------------------------------------------------------------

## Data models

Models are pure Dart objects (no Firebase imports) and include `toMap()` and
`fromMap()` helpers.

- UserModel
	- `uid`, `username`, `email`
	- Use for representing user profiles stored in Firestore under `users/{uid}`.

- ChatModel
	- `id`, `participants` (List<String>), `lastMessage`, `lastUpdatedAt`
	- Stored in Firestore as chat metadata (helps chat list UI and search).

- MessageModel
	- `id`, `chatId`, `senderId`, `text`, `timestamp` (DateTime)
	- Messages are written to Realtime Database under `/messages/{chatId}/{messageId}`
		with fields `senderId`, `text`, `timestamp` (ms since epoch).

--------------------------------------------------------------------------------

## ChatService (Realtime Database)

Location: `lib/services/chat_service.dart`

Key responsibilities:
- sendMessage({ chatId, senderId, text })
	- Generates a push key under `/messages/{chatId}` and writes a message node
		{ senderId, text, timestamp }.
	- Does not update Firestore chat metadata (left to another service / teammate).

- messagesStream(chatId) -> Stream<List<MessageModel>>
	- Listens to `/messages/{chatId}` ordered by child `timestamp`, maps snapshots
		to `List<MessageModel>` sorted ascending.

UI integration example:

```dart
final chatService = ChatService();

StreamBuilder<List<MessageModel>>(
	stream: chatService.messagesStream(chatId),
	builder: (context, snapshot) {
		final messages = snapshot.data ?? [];
		return ListView.builder(...);
	},
)

// Sending:
await chatService.sendMessage(chatId: chatId, senderId: uid, text: "Hello");
```

--------------------------------------------------------------------------------

## Authentication & navigation flow

- App initializes Firebase in `main()` and shows `AuthGate`.
- `AuthGate` listens to `FirebaseAuth.instance.authStateChanges()` and
	shows `LoginScreen` when unauthenticated or `ChatListScreen` when signed in.
- `LoginScreen` and `RegisterScreen` are minimal email/password forms that
	call Firebase Auth. Registration also writes a user profile in Firestore
	using `UserService.createUserProfile(...)`.

--------------------------------------------------------------------------------

## Firebase security rules (examples)

These are starting points. You must adapt rules to your project and test
them in the Firebase Console. Keep rules restrictive in production.

**Realtime Database rules (basic example):**

```json
{
	"rules": {
		"messages": {
			"$chatId": {
				".read": "auth != null && auth.uid in data.parent().parent().child('participants').val()",
				".write": "auth != null && auth.uid == newData.child('senderId').val()"
			}
		}
	}
}
```

Note: Above is illustrative; implement participant checks in your data model
and rules carefully.

**Firestore rules (users and chats):**

```firestore
rules_version = '2';
service cloud.firestore {
	match /databases/{database}/documents {
		match /users/{userId} {
			allow read: if request.auth != null;
			allow write: if request.auth != null && request.auth.uid == userId;
		}

		match /chats/{chatId} {
			allow read: if request.auth != null && request.auth.uid in resource.data.participants;
			allow write: if request.auth != null && request.auth.uid in request.resource.data.participants;
		}
	}
}
```

--------------------------------------------------------------------------------

## Testing, analysis & formatting

- Run static analysis:

```powershell
flutter analyze
```

- Format code:

```powershell
flutter format .
```

- Unit & widget tests: add tests under `test/` and run with:

```powershell
flutter test
```

--------------------------------------------------------------------------------

## Contributors

- Abdelrahman Ihab Shafie
- Aliaa Omar
- Nada Magdy
- Mohamed Ahmed Mohamed Kamel
- Mohamed Ashraf

