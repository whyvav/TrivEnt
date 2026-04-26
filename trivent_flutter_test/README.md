# trivent_flutter_test

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


# Run (Chrome, web app, locally)
flutter run -d chrome

# Deployment (Web -- via GitHub to Vercel) Steps
After making a change, to publish to Vercel:
flutter build web --release
git add trivent_flutter_test/build/web
git add .
git commit -m "commit x comment"
git push

# Deployment (Phone App)
flutter build apk --release
Then manual updates, e.g., USB transfer or or WhatsApp or Google Drive