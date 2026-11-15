# Eagle Jobs (Client & Worker)

Eagle Jobs iOS app for clients and workers: post and book jobs, chat, payments, wallet and account management.

Built with SwiftUI (iOS 26.2), talking to the Eagle Jobs API (`Networking/APIClient.swift`).

## Run

Open `Eagle construction.xcodeproj` in Xcode and run on an iPhone simulator, or build without Xcode:

```bash
./run-without-xcode.sh
```

Debug builds can point at a local server with the launch argument `-apiBaseURL http://127.0.0.1:3000/api`.

## Structure

- `DesignSystem/`: theme, cards, form controls, shared components
- `Networking/`: API client, endpoints, models
- `Navigation/`, `State/`: navigator and session
- `Screens/`: app screens
- `Services/`: media picker, location
