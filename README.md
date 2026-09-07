# SurAdda (Flutter App)

**SurAdda** — *sur* (melody) + *adda* (casual social gathering) — is a social music streaming app built for Bangladeshi users, submitted to the BdApps National Android Development Bootcamp. It combines cloud and on-device music playback with real-time, synchronized group listening — both over the internet and over a local WiFi hotspot with no internet connection required.

## Tech Stack

- **Framework:** Flutter
- **Architecture:** MVVM
- **State management:** Provider
- **Dependency injection:** GetIt
- **Audio playback:** just_audio
- **Local device audio:** on_audio_query
- **Local network discovery:** bonsoir (mDNS)
- **Networking:** Dio (REST) + web_socket_channel (real-time sync)

## Features

### Music Library
- **Cloud tab** — browse and stream the shared catalogue (Cloudinary-hosted), with search by title or artist
- **Local tab** — browse and play audio already on the device, with embedded artwork
- A single shared playback engine handles both sources transparently through a common `PlayableTrack` interface, so switching between a cloud song and a local file is seamless

### Persistent Player
- A slim mini-player ("slab") stays visible above the bottom navigation across every screen in the app
- Tapping it expands into a full-screen player with Hero-animated artwork, seek bar, and playback controls
- Play/pause, seek, and skip next/previous all work consistently whether listening solo or in a party

### Online Parties
- Create or join a listening party using a short, shareable code — no account lookup or friend list needed
- One person hosts; everyone else's playback mirrors the host's in real time (play, pause, seek, track changes)
- Live "who's in the party" list, with the host clearly marked
- Listeners can watch full player state (position, artwork, now-playing) but cannot control playback — only the host drives the session
- The party persists across app navigation — switching tabs to browse the library or check other screens doesn't end the session; only an explicit "leave" does

### Hotspot Parties (offline)
- Share music with nearby devices over a WiFi hotspot, with **no internet connection required on either side**
- The host serves audio directly from their device; other phones discover the host automatically via local network service discovery
- Same host-authoritative sync model as online parties — play, pause, seek, and track switches all propagate live
- Only songs physically present on the host's device can be shared — cloud tracks are intentionally excluded from this mode, and attempting to use one shows a clear explanation why

### Authentication
- Persistent login backed by JWT access and refresh tokens, refreshed automatically in the background
- Identity is tied to phone number, in preparation for carrier-billed subscription and OTP-based verification through bdapps
- A navigation drawer provides access to account details and subscription management

### Subscription Awareness
- The app is built to gracefully distinguish "not logged in" from "logged in but subscription lapsed," each with its own clear state rather than a generic error
- Designed around bdapps' carrier billing model, where subscription status can change outside the app (via SMS/USSD) and needs to be reflected without requiring the user to log out and back in

## Project Structure

```
lib/
├── core/                  Constants, theming, networking, utilities
├── data/                  Models, repositories, remote data sources
├── services/              Audio playback, auth token storage, streaming (online & hotspot)
├── presentation/
│   ├── viewmodels/        One per feature area (auth, library, online room, hotspot room)
│   ├── views/             Screens, grouped by feature
│   └── widgets/           Shared components (mini-player, nav bar, drawer)
└── di/                    GetIt service locator setup
```

## Design Principles Followed

- **Single source of truth for playback** — one `PlaybackService` instance backs every screen, so party mode, solo listening, and the mini-player never fall out of sync with each other
- **Host-authoritative sync** — in any party (online or hotspot), only the host's actions drive shared state; listeners' local controls are disabled by design, not just by convention
- **Persistent, singleton view models** for anything that needs to survive navigation (an active party, the audio engine) — created once via GetIt and provided app-wide, rather than tied to a single screen's lifecycle

## Running Locally

```bash
flutter pub get
flutter run
```

Requires a running instance of the [SurAdda backend](https://github.com/Salmee12/suradda-backend) — update the API base URL in `lib/core/constants/api_constants.dart` to point at your deployed or local backend instance.