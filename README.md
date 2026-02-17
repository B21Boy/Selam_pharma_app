# SHMed

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## AI Integration

This app supports an AI-powered medicine recommendation workflow. To enable it:

- Add your OpenAI-style API key to a `.env` file at the project root (see `.env.sample`).
- Do NOT commit `.env` to source control.
- Run `flutter pub get` after updating dependencies.

Security notes:

- Never hardcode or share your API key. Keep it in `.env` and out of Git.
- The AI feature is limited: it should only recommend medicines already present in the app's Hive database. Validate AI responses before showing them to users.
