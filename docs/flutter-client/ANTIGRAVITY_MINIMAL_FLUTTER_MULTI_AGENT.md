# OfflineAcademy Minimal Flutter Client — Multi-Agent Antigravity Build Plan

## 1. Objective

Build the smallest testable Flutter client for the existing OfflineAcademy system.

Targets:
- Android
- Windows

Immediate user flow:

```text
Launch app
→ enter OfflineAcademy server URL
→ test connection
→ save server URL
→ load real courses
→ open a real course
→ show real modules and lessons
→ open a VIDEO lesson
→ play the real video
→ seek forward/backward
```

This is a proof-of-function release. Do not expand scope beyond what is required to make this flow work reliably.

## 2. Existing Backend Facts

The discovery phase has already established:

- OfflineAcademy is a Next.js 14 full-stack app.
- Backend and frontend run in one Next.js process.
- Docker host port: `6969`.
- Container port: `6767`.
- Database: SQLite via Prisma.
- Course media lives under `My_Courses`.
- No authentication exists.
- No JWT.
- No cookies.
- No CSRF.
- No user login.
- Progress uses hardcoded user `local-user`.
- Course API exists: `GET /api/courses`.
- Lesson API exists: `GET /api/lesson/[lessonId]`.
- Progress API exists: `POST /api/progress`.
- Media API exists: `GET /api/files/{filePath}`.
- Media streaming supports HTTP Range requests and `206 Partial Content`.
- The current missing API capability is `GET /api/courses/[slug]`.

The Flutter client must reuse this architecture. Do not redesign the backend.

## 3. Agent Assignment Strategy

### Critical Agent — Claude Sonnet 4.6 (Thinking)

Use Sonnet for work where a wrong decision could break architecture, backend behavior, media playback, networking, platform setup, or cause expensive debugging.

Sonnet owns:
- backend modification,
- API contract decisions,
- Flutter project architecture,
- networking architecture,
- server URL handling strategy,
- URI/path encoding strategy,
- media player integration,
- Android platform/network configuration,
- Windows media/platform issues,
- difficult runtime bugs,
- cross-platform playback bugs,
- final integration review.

### Routine Agent — Gemini 3.7 Flash Medium

Use Flash for implementation volume once Sonnet has established the architecture.

Flash owns:
- normal widgets,
- course cards,
- lesson list UI,
- loading/empty/error states,
- simple Riverpod wiring that follows the existing architecture,
- `shared_preferences` persistence,
- basic navigation wiring,
- basic responsive layout,
- formatting,
- documentation,
- straightforward analyzer errors,
- running build/test commands,
- simple fixes with obvious root causes.

## 4. Mandatory Escalation Rule

Flash must NOT redesign architecture.

If Flash encounters any of the following, STOP that task and escalate it to Sonnet:
- an API does not match the documented contract,
- a backend change appears necessary,
- media does not play,
- seeking does not work,
- URL/path encoding behaves incorrectly,
- Android cannot connect,
- Windows playback fails,
- a package behaves differently across Android and Windows,
- a solution requires changing platform security configuration,
- a solution requires changing Docker or Next.js backend behavior,
- a fix requires replacing a package,
- a fix requires introducing a new architectural abstraction,
- a build/runtime issue is not clearly routine.

Flash may explain the problem, but must not invent a workaround.

## 5. Model Usage Principle

Use Sonnet for **decisions**.

Use Flash for **execution volume**.

Do not waste Sonnet quota on repetitive widget code, simple UI layout, formatting, obvious boilerplate, normal documentation, or basic test command execution.

Do not waste time by asking Flash to solve architecture-sensitive failures repeatedly.

## 6. Phase Ownership Summary

| Phase | Task | Primary Agent |
|---|---|---|
| 0 | Verify actual backend behavior | Sonnet |
| 1 | Add `GET /api/courses/[slug]` | Sonnet |
| 2 | Create Flutter architecture/skeleton | Sonnet |
| 3 | Build connection screen UI | Flash |
| 4 | Implement API client + models | Sonnet |
| 5 | Build courses screen | Flash |
| 6 | Build course/modules/lessons screen | Flash |
| 7 | Implement media URL construction | Sonnet |
| 8 | Integrate `media_kit` player | Sonnet |
| 9 | Build player screen UI | Flash |
| 10 | Add resume position | Sonnet |
| 11 | Android local HTTP/platform config | Sonnet |
| 12 | Basic responsive polish | Flash |
| 13 | Analyzer/build cleanup | Flash first, Sonnet if escalated |
| 14 | Real playback debugging | Sonnet |
| 15 | Final verification/report | Sonnet |

## 7. Phase 0 — Verify Actual Backend

### Owner
**Claude Sonnet 4.6 Thinking**

### Goal
Confirm the running OfflineAcademy instance behaves like the discovery documents describe.

Read first:
```text
docs/flutter-client/backend-contract.md
docs/flutter-client/flutter-minimum-build-summary.md
```

Also inspect the source files referenced by those documents.

If the actual backend is reachable, verify:
```text
GET /api/settings
GET /api/courses?limit=20
```

Find one real video lesson where possible.

Probe its media URL using:
```text
Range: bytes=0-1023
```

Expected behavior:
```text
206 Partial Content
Accept-Ranges: bytes
Content-Range: ...
```

Do not invent runtime test results. If the Docker instance is unavailable, continue using the verified source contract and clearly mark runtime validation as unavailable.

## 8. Phase 1 — Add Missing Course Details API

### Owner
**Claude Sonnet 4.6 Thinking**

Add:
```text
GET /api/courses/[slug]
```

to:
```text
app/api/courses/[slug]/route.ts
```

Reuse existing query patterns from:
```text
app/course/[slug]/page.tsx
app/api/lesson/[lessonId]/route.ts
```

Return enough data for:
```text
Course
→ Modules
→ Lessons
```

Preserve ordering.

Lesson fields required:
```text
id
title
order
type
filePath
fileName
mimeType
duration
progress
```

Reuse current `local-user` progress semantics.

Do not modify Prisma schema, run migrations, change existing records, add authentication, modify existing route behavior, change progress semantics, change Docker behavior, or refactor unrelated backend code.

Where the backend is available, verify `GET /api/courses/{realSlug}` returns real modules and lessons.

## 9. Phase 2 — Flutter Project Skeleton

### Owner
**Claude Sonnet 4.6 Thinking**

Create:
```text
clients/flutter/
```

Targets:
```text
Android
Windows
```

Use Flutter stable.

Recommended structure:
```text
lib/
  main.dart
  app/
    router.dart
  core/
    config/
    network/
  features/
    connection/
    courses/
    player/
```

Use:
```text
flutter_riverpod
go_router
shared_preferences
media_kit
media_kit_video
media_kit_libs_video
```

Choose either `http` or `dio`. Prefer the simpler choice because the backend has no authentication.

Do not add `freezed`, `drift`, `sqlite`, `hive`, secure storage, authentication packages, or download managers unless a concrete requirement appears.

Sonnet must establish project structure, router structure, providers/dependency structure, networking approach, base URL storage approach, and typed core models strategy before handing routine work to Flash.

## 10. Phase 3 — Connection Screen

### Owner
**Gemini 3.7 Flash Medium**

Follow the architecture created by Sonnet.

Build:
```text
Connect to OfflineAcademy
```

UI:
```text
Server URL text field
Test Connection button
Connection status/error
```

Accepted examples:
```text
http://192.168.1.100:6969
http://10.0.2.2:6969
https://academy.example.com
```

Persist successful server URL using `shared_preferences`.

Connection test:
```text
GET {BASE_URL}/api/settings
```

A random HTML `200 OK` response is not sufficient. Validate that the response matches expected OfflineAcademy settings JSON.

Use friendly errors such as:
```text
Cannot reach server
Connection timed out
Invalid OfflineAcademy server
Server returned an error
```

Do not expose raw stack traces.

Flash must escalate if URL normalization is ambiguous, redirect behavior is unexpected, HTTPS/TLS issues occur, Android networking fails, or the backend response differs from the contract.

## 11. Phase 4 — API Client and Models

### Owner
**Claude Sonnet 4.6 Thinking**

Implement the real API layer.

Required calls:
```text
GET /api/settings
GET /api/courses?page=1&limit=100
GET /api/courses/{slug}
```

Optionally prepare `POST /api/progress`, but progress writing is not required for this proof.

Create only models needed for:
```text
Course
Module
Lesson
Progress
Pagination
```

Do not create repository-interface layers, use cases, or DTO → entity → view-model chains unless a real requirement appears.

Sonnet must ensure API parsing matches the actual backend.

## 12. Phase 5 — Courses Screen

### Owner
**Gemini 3.7 Flash Medium**

Request:
```text
GET {BASE_URL}/api/courses?page=1&limit=100
```

Display real course data.

Show only:
- `displayName` if present, otherwise `name`,
- thumbnail if easy and reliable,
- progress percentage if present.

Handle loading, empty, error, and success states.

Do not build search, filters, favorites, sorting UI, categories, tags, or animations.

Flash must escalate if response parsing fails, thumbnail URLs require non-trivial backend handling, or course data differs from the contract.

## 13. Phase 6 — Course / Module / Lesson Screen

### Owner
**Gemini 3.7 Flash Medium**

When a course is selected:
```text
GET {BASE_URL}/api/courses/{encodedSlug}
```

Display:
```text
Course title

Module
  Lesson
  Lesson

Module
  Lesson
```

Preserve backend order and clearly identify VIDEO lessons.

No dashboard, advanced metadata views, or progress dashboard.

Flash must escalate if endpoint behavior differs, ordering is unclear, lesson types are inconsistent, or the backend returns unexpected nested data.

## 14. Phase 7 — Media URL Construction

### Owner
**Claude Sonnet 4.6 Thinking**

Construct the media URL from:
```text
BASE_URL
+
/api/files/
+
lesson.filePath
```

Do not concatenate an unescaped filesystem path blindly.

Correctly encode each path segment while preserving `/` separators.

The solution must safely support filenames/folders containing:
```text
spaces
parentheses
brackets
Unicode
#
%
?
&
```

Verify using at least one real media path where available.

## 15. Phase 8 — Native Video Playback

### Owner
**Claude Sonnet 4.6 Thinking**

Use:
```text
media_kit
media_kit_video
media_kit_libs_video
```

Initialize `media_kit` correctly before application startup.

Play the real OfflineAcademy media URL.

Requirements:
```text
play
pause
seek
duration
current position
```

Fullscreen may be included if straightforward.

Do not download the entire file before playback. The player must rely on existing HTTP Range streaming.

Verify media opens, playback begins, seek forward works, and seek backward works.

Sonnet owns player initialization, media source behavior, codecs/container issues, Windows-specific playback behavior, Android-specific playback behavior, and range/seeking issues.

Do not delegate player integration debugging to Flash.

## 16. Phase 9 — Player Screen UI

### Owner
**Gemini 3.7 Flash Medium**

Once Sonnet proves playback architecture works, Flash may build/refine the surrounding screen.

Required UI only:
```text
video
play/pause
seek bar
position
duration
back navigation
```

Do not build custom advanced controls. If standard `media_kit` controls satisfy requirements, use them.

Flash must escalate if any UI issue is actually a playback/controller/platform issue.

## 17. Phase 10 — Resume Position

### Owner
**Claude Sonnet 4.6 Thinking**

Use:
```text
lesson.progress.position
```

If a saved position exists, seek to it after the media becomes ready.

Do not seek before the player is in a valid state.

For this checkpoint:
```text
READ resume position = REQUIRED
WRITE progress = OPTIONAL
```

Do not let progress writing delay the first working app.

## 18. Phase 11 — Android Networking Configuration

### Owner
**Claude Sonnet 4.6 Thinking**

Local testing may use:
```text
http://LAN_IP:6969
```

Configure development/testing support safely.

Preferred approaches:
- debug-specific Android manifest/configuration,
- Android Network Security Configuration where appropriate.

Do not disable TLS certificate validation, create trust-all clients, or unnecessarily weaken production HTTPS behavior.

HTTPS remains preferred through Synology reverse proxy for normal remote use.

## 19. Phase 12 — Basic Responsive Polish

### Owner
**Gemini 3.7 Flash Medium**

Only after the functional flow works.

Android:
- usable on phone,
- touch targets sensible,
- portrait works.

Windows:
- sensible window sizing,
- mouse interaction works,
- video scales correctly.

Do not build separate complex Android and Windows designs.

No dark mode, animations, desktop redesign, or advanced theming.

## 20. Phase 13 — Analyzer and Build Cleanup

### Primary Owner
**Gemini 3.7 Flash Medium**

Run:
```text
flutter analyze
flutter test
flutter build windows
flutter build apk --debug
```

Flash may fix unused imports, obvious nullability issues, formatting, simple type mismatches, obvious widget errors, and straightforward lint issues.

Escalate to Sonnet if platform build fails, media dependency fails, networking configuration fails, plugin initialization fails, Windows native dependency fails, Android Gradle/platform issues are non-trivial, or the fix would alter architecture.

## 21. Phase 14 — Real Playback Debugging

### Owner
**Claude Sonnet 4.6 Thinking**

Use a real OfflineAcademy server where available.

Test:
```text
Launch
→ connect
→ courses load
→ open course
→ lessons load
→ open VIDEO lesson
→ playback starts
→ seek forward
→ seek backward
→ pause
→ resume
```

Sonnet owns all failures in this phase.

Do not route playback failures back to Flash repeatedly.

## 22. Phase 15 — Final Verification

### Owner
**Claude Sonnet 4.6 Thinking**

Verify:
```text
flutter analyze
flutter test
flutter build windows
flutter build apk --debug
```

Verify actual application behavior where devices/environments are available.

Do not claim runtime success without actual runtime testing.

If Android device/emulator is unavailable:
```text
ANDROID BUILD: PASS
ANDROID PLAYBACK: UNVERIFIED
```

Also verify the existing OfflineAcademy web app remains operational.

## 23. Completion Criteria

This checkpoint is complete when:
```text
Windows build works
Android debug APK builds
Server URL can be configured
Real courses load
Real modules/lessons load
Real video plays on at least one available target
Seeking works on tested target
Resume position is read
Existing web app remains functional
```

Then stop.

## 24. Explicit Non-Goals

Do not implement:
```text
offline downloads
quiz UI
search
favorites
course editing
notifications
authentication
AI features
advanced settings
installer
auto-update
dark mode
progress dashboard
custom video UI polish
multi-user support
cloud sync
```

These may be added later as separate small checkpoints.

## 25. Backend Safety Rule

The ONLY authorized backend modification in this build is:
```text
GET /api/courses/[slug]
```

If anything else appears necessary:
```text
STOP
DOCUMENT
ESCALATE TO SONNET
```

Do not modify backend behavior without explicit approval.

## 26. Final Report Format

At completion produce:

### Backend Change
What changed for `GET /api/courses/[slug]`.

### Agent Usage
List every phase and which model handled it, and every escalation from Flash to Sonnet.

### Flutter Structure
Files/features created.

### Dependencies
Packages added and why.

### Server Test
Tested using one of:
```text
localhost
LAN
HTTPS reverse proxy
unavailable
```

### Course Test
Did real courses load?
```text
PASS / FAIL / UNVERIFIED
```

### Lesson Test
Did real modules/lessons load?
```text
PASS / FAIL / UNVERIFIED
```

### Video Test
State:
```text
media/container tested
playback result
seek forward result
seek backward result
resume-position result
```

### Windows
```text
BUILD: PASS / FAIL
PLAYBACK: PASS / FAIL / UNVERIFIED
```

### Android
```text
BUILD: PASS / FAIL
PLAYBACK: PASS / FAIL / UNVERIFIED
```

### Existing Web App
```text
PASS / FAIL / UNVERIFIED
```

### Problems
List only actual remaining problems.

### Verdict
Return exactly one:
```text
MINIMAL FLUTTER CLIENT WORKING
```

or:
```text
MINIMAL FLUTTER CLIENT NEEDS REVIEW
```

Then stop.

## 27. Antigravity Execution Instruction

Read this entire file before starting.

Follow the model ownership rules exactly.

Use **Claude Sonnet 4.6 Thinking** for critical architecture, backend, API, networking, media, platform, debugging, and final-integration work.

Use **Gemini 3.7 Flash Medium** for routine UI, boilerplate, simple state wiring, persistence, straightforward cleanup, builds, tests, and documentation.

Flash must never redesign a decision made by Sonnet.

When Flash encounters a critical or ambiguous technical issue, stop that task and escalate only that issue to Sonnet.

Do not use Claude Opus unless explicitly requested later.

Do not expand project scope.

Build the smallest reliable Android + Windows client that connects to the existing OfflineAcademy backend and plays real course video.

Then stop.
