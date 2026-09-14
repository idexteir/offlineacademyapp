We have completed the OfflineAcademy discovery phase.

Read these files completely before changing anything:

- `docs/flutter-client/backend-contract.md`
- `docs/flutter-client/flutter-minimum-build-summary.md`

Also inspect the relevant source files referenced by those documents before implementing changes.

We are now building the smallest possible proof-of-concept Flutter client.

# Goal

Build ONE Flutter codebase targeting:

- Android
- Windows

The only required user flow is:

```text
Launch app
→ enter OfflineAcademy server URL
→ test connection
→ save server URL
→ retrieve real courses
→ select course
→ retrieve its real modules/lessons
→ select VIDEO lesson
→ construct real media URL
→ play video
→ seek within video
```

Do not expand the scope.

# 1. First Verify the Existing Docker Instance

Before Flutter implementation, test the actual running OfflineAcademy backend if it is reachable from this development machine.

Verify:

```text
GET /api/settings
GET /api/courses?limit=20
```

Then identify one real course and one real video from the running installation if possible.

Verify the actual media endpoint with a Range request such as:

```text
Range: bytes=0-1023
```

Confirm the server returns:

```text
206 Partial Content
Accept-Ranges: bytes
Content-Range: ...
```

If the Docker instance is not reachable from the development environment, report that and continue based on the verified source contract.

Do not invent test results.

# 2. Add the Missing Course Details Endpoint

The discovery found that `/api/courses` does not expose lesson IDs required to enter an unwatched course.

Add:

```text
GET /api/courses/[slug]
```

to the existing:

```text
app/api/courses/[slug]/route.ts
```

This must be a READ-ONLY additive endpoint.

Reuse the existing Prisma models and query patterns already used by:

```text
app/course/[slug]/page.tsx
app/api/lesson/[lessonId]/route.ts
```

The endpoint must return enough information for Flutter to display:

```text
Course
→ Modules in correct order
→ Lessons in correct order
```

For lessons include the existing fields required for playback:

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

Reuse existing progress semantics for `local-user`.

Do NOT:

- modify the Prisma schema,
- run migrations,
- modify existing records,
- change existing routes,
- change progress behavior,
- add authentication,
- restructure the backend.

Test the new endpoint against a real course if the Docker/development instance is available.

# 3. Create Flutter Client

Create:

```text
clients/flutter/
```

Use Flutter stable.

Target only:

```text
Android
Windows
```

Do not configure iOS, macOS, Linux or Flutter Web unless Flutter tooling creates unavoidable default files. Do not spend time implementing them.

# 4. Dependencies

Keep dependencies minimal.

Use:

```text
flutter_riverpod
go_router
http OR dio
media_kit
media_kit_video
media_kit_libs_video
shared_preferences
```

Choose either `http` or `dio`.

Because the current backend has no authentication, cookies, CSRF or token refresh, prefer the simpler option unless a concrete implementation requirement justifies Dio.

Do not add:

```text
freezed
drift
sqlite
hive
secure storage
download managers
authentication libraries
```

unless this checkpoint proves one is genuinely necessary.

# 5. Server Connection Screen

On first launch show:

```text
Connect to OfflineAcademy
```

Provide:

```text
Server URL field
Test Connection button
```

Example accepted values:

```text
http://192.168.1.100:6969
http://10.0.2.2:6969
https://academy.example.com
```

Normalize the URL.

Test using:

```text
GET {BASE_URL}/api/settings
```

Do not consider arbitrary HTTP 200 HTML a successful OfflineAcademy connection.

Verify the response looks like the expected OfflineAcademy settings JSON.

If successful:

- save base URL using shared_preferences,
- continue to Courses.

If unsuccessful show a useful error.

Examples:

```text
Cannot reach server
Connection timed out
Invalid OfflineAcademy server
Server returned an error
```

Do not display raw stack traces.

# 6. Android Local HTTP

The existing installation may be accessed over LAN using:

```text
http://LAN_IP:6969
```

Development Android builds therefore need local HTTP support.

Configure this safely for development/testing.

Do not disable TLS validation.

Do not implement trust-all certificates.

HTTPS remains the preferred deployment path through the Synology reverse proxy.

# 7. Courses Screen

Request:

```text
GET {BASE_URL}/api/courses?page=1&limit=100
```

Display real course data.

For this proof of concept only show:

```text
course displayName if available, otherwise name
thumbnail if easily usable
progress percentage if available
```

Do not build:

```text
search
filters
favorites
sorting UI
categories
tags
animations
```

Handle:

```text
loading
empty
error
success
```

# 8. Course Screen

When the user taps a course call:

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

Preserve backend ordering.

Clearly identify VIDEO lessons.

No additional course dashboard is needed.

# 9. Video Playback

When a VIDEO lesson is selected:

Construct the media URL from:

```text
BASE_URL
+
/api/files/
+
lesson.filePath
```

IMPORTANT:

Do not concatenate an unescaped filesystem path blindly.

Build the URI safely while preserving `/` path separators and correctly encoding each individual path segment.

The implementation must correctly handle:

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

in folder/file names.

Use:

```text
media_kit
media_kit_video
media_kit_libs_video
```

Initialize media_kit correctly before application startup.

Player screen needs only:

```text
video
play/pause
seek bar
current position
duration
fullscreen if straightforward
back navigation
```

Do not build custom advanced player controls unless required.

Seeking must use the existing server's HTTP Range implementation.

Do not download the complete video before playback.

# 10. Resume Position

If the course-details response provides:

```text
progress.position
```

seek to that position after the media becomes ready.

For this checkpoint, reading the existing resume position is required.

Writing progress back to the backend is OPTIONAL.

Do not let progress-writing logic delay proving playback.

# 11. Responsive UI

Keep UI extremely simple.

Android:

```text
phone-friendly
touch-friendly
portrait works correctly
```

Windows:

```text
reasonable window layout
mouse usable
video scales correctly
```

Do not spend time creating separate desktop/mobile designs yet.

Functional adaptive layout is enough.

# 12. Architecture

Use a lean structure.

Example:

```text
lib/
  main.dart

  core/
    config/
    network/

  features/
    connection/
    courses/
    player/
```

Use Riverpod for:

```text
configured server URL
API dependencies
course state
```

Use go_router for navigation.

Do not introduce Clean Architecture boilerplate.

No unnecessary:

```text
repository interfaces
use cases
domain abstractions
DTO → entity → view model chains
```

Simple typed models are enough.

# 13. Backend Must Remain Compatible

The existing web/PWA must continue working unchanged.

The only backend modification authorized in this checkpoint is:

```text
GET /api/courses/[slug]
```

If anything else appears necessary:

STOP.

Document it instead of implementing it.

# 14. Validation

Before declaring success run:

```text
flutter analyze
flutter test
flutter build windows
flutter build apk --debug
```

Fix analyzer errors.

Then test the actual flow when the backend is reachable:

```text
Launch
→ connect
→ courses appear
→ open real course
→ real lessons appear
→ open real VIDEO lesson
→ video starts
→ seek forward
→ seek backward
→ pause
→ resume
```

Do not claim playback works unless it was actually tested.

If Android hardware/emulator is available, test there.

If it is unavailable:

```text
ANDROID BUILD: VERIFIED
ANDROID PLAYBACK: UNVERIFIED
```

Do not invent runtime validation.

# 15. Stop Condition

This checkpoint is COMPLETE when:

```text
Windows build works
Android debug APK builds
Server URL can be configured
Real courses load
Real course modules/lessons load
Real video plays on at least one available target
Seeking works on the tested target
Existing OfflineAcademy web client remains functional
```

Then STOP.

Do not implement:

```text
offline downloads
quiz UI
search
favorites
course editing
notifications
authentication
AI
advanced settings
installer
auto-update
dark mode
progress dashboards
custom video UI polish
```

# 16. Final Report

At completion report exactly:

## Backend Change
What was changed for `GET /api/courses/[slug]`.

## Flutter Structure
Files/features created.

## Dependencies
Packages added and why.

## Server Test
Actual backend URL type tested: localhost / LAN / HTTPS / unavailable.

## Course Test
Whether real courses and lessons loaded.

## Video Test
File/container tested.
Playback result.
Seeking result.

## Windows
BUILD: PASS / FAIL
PLAYBACK: PASS / FAIL / UNVERIFIED

## Android
BUILD: PASS / FAIL
PLAYBACK: PASS / FAIL / UNVERIFIED

## Existing Web App
PASS / FAIL / UNVERIFIED

## Problems
Any actual remaining problems.

## Verdict

Return exactly one:

```text
MINIMAL FLUTTER CLIENT WORKING
```

or

```text
MINIMAL FLUTTER CLIENT NEEDS REVIEW
```

Then stop.