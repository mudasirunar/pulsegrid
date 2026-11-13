# Pulse Grid

Offline-first mobile application for emergency incident reporting, responder dispatch, and field resource coordination. Built with Flutter, SQLite as the local single source of truth, and Cloud Firestore for real-time cross-device synchronization.

---

## Core Capabilities

- **Offline-First Operation**: Full read/write functionality without network connectivity. All incidents, assignments, resource logs, and audit events are written to local SQLite first and queued for background synchronization.
- **Role-Based Access Control (RBAC)**:
  - **Coordinator**: Create and edit/delete any incident, assign or reassign responders, advance statuses, log resources, and close resolved incidents.
  - **Responder**: Report incidents, edit/delete unassigned incidents they created, advance status and log resources on incidents assigned to them.
  - **Viewer**: Read-only access to the live dashboard, incident details, resource summaries, and activity timeline.
- **Validated Incident Lifecycle**: Enforces sequential transitions (`New` -> `Assigned` -> `In Progress` -> `Resolved` -> `Closed`) through domain-level state machine validation and role checks, mirrored in `firestore.rules`.
- **Resource Logging & Aggregation**: Logs supplies (`Water`, `First Aid Kits`, `Oxygen`, `Blankets`, `Fuel`, or custom types) with positive quantity validation and per-incident grouped totals.
- **Chronological Activity Timeline**: Records creation, status changes, responder assignments, edits, and resource logs in local 12-hour time with live user display-name resolution.
- **Location & Multi-Photo Capture**: GPS coordinate and reverse-geocoded address capture with manual location fallback, plus up to 5 compressed local/Base64-synced attachments per incident.
- **Dashboard & Profile Controls**: Live operational metrics, search by title/ID, multi-criteria filtering and sorting (`Newest`, `Oldest`, `Latest Update`, `Severity`), role-aware profile stats, `System` / `Light` / `Dark` theme switching, haptic feedback toggle, and compact card density toggle.

---

## Tech Stack

| Layer | Technology |
| :--- | :--- |
| Framework | Flutter (Dart SDK `^3.13.3`, Material 3) |
| State Management | `flutter_bloc` (`Bloc` & `Cubit`), `equatable` |
| Dependency Injection | `get_it` |
| Local Persistence | `sqflite` (5 relational tables), `shared_preferences`, `path_provider` |
| Remote Backend | `firebase_core`, `firebase_auth`, `cloud_firestore` |
| Connectivity & Sensors | `connectivity_plus`, `geolocator`, `geocoding`, `image_picker`, `permission_handler` |

---

## Offline-First Architecture

```
UI (BLoC / Cubit)
   │
   ▼
Repository Layer ──► LocalDataSource (SQLite) ──► onTableChanged Stream ──► Reactive UI
   │                        │
   │                        ▼
   │                 sync_operations queue (FIFO + exponential backoff)
   │                        │
   └──────────────────► SyncEngine ◄──► FirestoreRemoteDataSource (snapshots / writes)
```

1. **SQLite as Single Source of Truth**:
   - Schema (`lib/core/database/app_database.dart`): `incidents`, `assignments`, `resource_logs`, `activity_events`, and `sync_operations`.
   - Every local mutation updates SQLite immediately and emits a table change event on `LocalDataSource.onTableChanged` so open screens update with zero polling.
2. **Write-Ahead Sync Queue**:
   - Offline or background mutations enqueue a `SyncOperationModel` (`PENDING`, `SYNCING`, `SYNCED`, `FAILED`) processed chronologically by `SyncQueueManager` with a concurrency guard and exponential backoff (`min(2^(retry-1), 60)s`).
   - Reconnecting via `NetworkInfo.onConnectivityChanged` automatically flushes pending operations and reconciles untracked local records.
3. **Real-Time Remote Sync & Conflict Strategy**:
   - `SyncEngine` subscribes to Cloud Firestore `snapshots()` listeners (guarded with `!metadata.hasPendingWrites`) for incidents, assignments, deletion tombstones, and `/users` profiles, plus scoped listeners for resource logs and activity events on the active detail screen.
   - Concurrent updates use **Last-Write-Wins (LWW)** based on UTC `updatedAt` timestamps (with `version` tie-breaking) and **Delete-Always-Wins** via `deleted_incidents` tombstones so deleted records are never resurrected by stale offline clients.
   - Photos are downsampled (`1024x1024`, 70% JPEG quality) and synced as Base64 payloads on incident documents, allowing cross-device media sync without external object storage billing.

---

## Project Structure

```
lib/
├── core/
│   ├── database/        # AppDatabase, DatabaseConstants, LocalDataSource
│   ├── errors/          # Exceptions & Failures
│   ├── network/         # Connectivity monitoring (NetworkInfo)
│   ├── preferences/     # AppPreferencesCubit (haptics, compact list)
│   ├── theme/           # AppColors, AppTheme (Light/Dark), ThemeCubit
│   ├── utils/           # DateTimeFormatter (12h local), PhotoFileResolver
│   └── widgets/         # Reusable UI primitives (AppButton, AppDialog, FloatingIslandNavBar, etc.)
└── features/
    ├── auth/            # Authentication, UserModel/RBAC, SignInScreen
    ├── dashboard/       # MainShellScreen, HomeScreen, metrics, search, filter/sort
    ├── incidents/       # State machine, permissions, CreateIncidentScreen, IncidentDetailsScreen
    ├── profile/         # ProfileScreen, ProfileStats, 3-way ThemePreviewSelector, animated toggles
    ├── resources/       # ResourceCubit, LogResourceBottomSheet, summary card
    └── sync/            # SyncEngine, SyncQueueManager, FirestoreRemoteDataSource, SyncBloc
```

---

## Getting Started

### Prerequisites

- Flutter SDK matching Dart `^3.13.3`
- Android Studio / Xcode for mobile targets
- A configured Firebase project (`lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`) with Email/Password Auth and Cloud Firestore enabled.

### Setup & Run

```bash
# Install dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run all unit and widget tests
flutter test

# Run on a connected device or emulator
flutter run

# Build release Android APK
flutter build apk --release
```

A prebuilt release APK is available at the repository root as `PulseGrid.apk`.

### Default Role Profiles (Quick Sign-In)

| Role | Email |
| :--- | :--- |
| Coordinator | `coordinator@pulsegrid.org` |
| Responder | `responder@pulsegrid.org` |
| Viewer | `viewer@pulsegrid.org` |
