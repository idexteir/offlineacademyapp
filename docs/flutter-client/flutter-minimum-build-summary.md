# OfflineAcademy Flutter Minimum Build Summary

## 1. Overall Architecture

OfflineAcademy is a self-hosted, single-process, full-stack Next.js 14 App Router service. It runs in a Docker container (Node 22 standalone) listening internally on port `6767`, mapped to host port `6969`.
- **Backend & API:** Next.js Route Handlers (`app/api/*`) running inside Node.js.
- **Database:** Local SQLite database accessed via Prisma ORM 5.12.0, persisted in `./prisma_data/dev.db` on host.
- **Media Storage:** Video course files reside in `./My_Courses` on the host, mounted to `/app/My_Courses` in the container.
- **Reverse Proxy:** Optional; the app can run on raw IP:Port on a local network or behind Caddy/Nginx.

## 2. Server Base URL

* **Host / Windows Desktop Client (Same machine):** `http://localhost:6969` or `http://127.0.0.1:6969`
* **Local LAN (Android device or other Windows PC):** `http://<SERVER_LAN_IP>:6969` (e.g. `http://192.168.1.100:6969`)
* **Android Emulator:** `http://10.0.2.2:6969`
* **Reverse Proxy (if configured):** `https://academy.lan` or `https://academy.example.com`

Reachability can be verified with a `GET` request to `/api/settings`.

## 3. Authentication

* **Type:** NONE.
* **Details:** OfflineAcademy is designed for single-user local/LAN deployments. There are no user accounts, passwords, sessions, JWTs, Bearer tokens, or CSRF tokens.
* **Hardcoded Identity:** All progress, bookmark, and history database records use the hardcoded identity `userId: "local-user"` (defined in `prisma/schema.prisma`).
* **Media Protection:** No authorization required to stream media files.

## 4. Course List
METHOD: GET
PATH: /api/courses
AUTH: None
RESPONSE:
```json
{
  "courses": [
    {
      "id": "cm1abcdef0000...",
      "name": "Test Course",
      "displayName": null,
      "slug": "test-course",
      "path": "/app/My_Courses/Test Course",
      "thumbnail": "/thumbnails/courses/test-course-thumb.jpg",
      "description": "Course overview description",
      "hidden": false,
      "favorited": false,
      "createdAt": "2026-06-17T12:00:00.000Z",
      "updatedAt": "2026-06-17T12:00:00.000Z",
      "_count": {
        "modules": 2,
        "lessons": 3
      },
      "progress": {
        "completedLessons": 0,
        "totalLessons": 3,
        "percentage": 0,
        "lastWatched": null
      },
      "tags": []
    }
  ],
  "tags": [],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 1,
    "totalPages": 1,
    "hasNext": false,
    "hasPrev": false
  }
}
```
NOTES: Supports query parameters `page`, `limit` (max 100), `search`, `filter` (`all`, `in-progress`, `completed`, `not-started`, `favorites`), `sortBy` (`updatedAt`, `name`, `progress`), and `sortOrder` (`asc`, `desc`). Source: `app/api/courses/route.ts`.

## 5. Course Details
METHOD: GET
PATH: /api/lesson/[lessonId] (Current) or /api/courses/[slug] (Recommended Small Change)
AUTH: None
RESPONSE:
```json
{
  "lesson": {
    "id": "clesson123",
    "title": "01 - Introduction",
    "slug": "01-introduction",
    "order": 0,
    "moduleId": "cmod123",
    "filePath": "Test Course/Module 1/01 - Introduction.mp4",
    "fileName": "01 - Introduction.mp4",
    "mimeType": "video/mp4",
    "duration": null,
    "thumbnail": null,
    "type": "VIDEO",
    "subtitlePath": null,
    "subtitles": [],
    "progress": {
      "id": "cprog123",
      "position": 142,
      "completed": false,
      "lastWatched": "2026-06-17T14:20:00.000Z"
    }
  },
  "course": {
    "id": "ccourse123",
    "name": "Test Course",
    "slug": "test-course",
    "modules": [
      {
        "id": "cmod123",
        "name": "Module 1",
        "slug": "module-1",
        "order": 0,
        "courseId": "ccourse123",
        "lessons": [
          {
            "id": "clesson123",
            "title": "01 - Introduction",
            "slug": "01-introduction",
            "order": 0,
            "moduleId": "cmod123",
            "filePath": "Test Course/Module 1/01 - Introduction.mp4",
            "fileName": "01 - Introduction.mp4",
            "mimeType": "video/mp4",
            "duration": null,
            "type": "VIDEO",
            "progress": {
              "id": "cprog123",
              "position": 142,
              "completed": false,
              "lastWatched": "2026-06-17T14:20:00.000Z"
            }
          }
        ]
      }
    ],
    "stats": {
      "totalLessons": 3,
      "completedLessons": 1,
      "percentage": 33
    }
  },
  "prevLesson": null,
  "nextLesson": {
    "id": "clesson124",
    "title": "02 - Setup"
  },
  "currentIndex": 0,
  "totalLessons": 3
}
```
NOTES: In the current backend, the web UI uses React Server Components directly for `/course/[slug]`, so `/api/courses/[slug]` currently only has `PATCH` and `DELETE`. However, `/api/lesson/[lessonId]` returns the entire course object including all modules, lessons, order, and progress. To open a course directly from `/api/courses` without knowing a lesson ID beforehand, adding a 15-line `GET` handler in `app/api/courses/[slug]/route.ts` is recommended (see Section 10).

## 6. Lesson List / Lesson Details
METHOD: GET
PATH: /api/lesson/[lessonId]
AUTH: None
RESPONSE: Returns both the requested lesson details and the full hierarchy of modules and lessons (same JSON response as Section 5).
NOTES: Key fields on `lesson`:
- `id`: unique lesson CUID
- `title`: human readable lesson title
- `filePath`: relative path from `COURSES_ROOT` (e.g. `Test Course/Module 1/01 - Introduction.mp4`)
- `type`: `"VIDEO"`, `"AUDIO"`, `"PDF"`, `"MARKDOWN"`, etc.
- `mimeType`: e.g. `"video/mp4"`, `"video/webm"`
- `progress`: `{ position: number, completed: boolean }`
Source: `app/api/lesson/[lessonId]/route.ts`.

## 7. Video Playback
MEDIA URL SOURCE: Derived from `lesson.filePath` returned by `/api/lesson/[lessonId]`
REQUEST METHOD: GET
AUTH: None
HTTP RANGE SUPPORT: YES (Status 206 Partial Content, `Accept-Ranges: bytes`, `Content-Range: bytes {start}-{end}/{total}`)
MIME TYPE: Dynamic based on file extension (`video/mp4`, `video/webm`, `video/x-matroska`, `video/quicktime`, etc.)
NOTES: Video files are served by `app/api/files/[...path]/route.ts`. The full playback URL is `{BASE_URL}/api/files/{Uri.encodeFull(lesson.filePath)}`. The server implements native Node `fs.createReadStream(actualPath, { start, end })` allowing native players (ExoPlayer/media_kit) to perform instant seeking without downloading the full file.

## 8. Minimum Flutter Request Flow

Server connection
→ Check reachability: `GET /api/settings` (Status 200)
→ Fetch course catalog: `GET /api/courses?page=1&limit=20`
→ Select course & retrieve lesson tree: `GET /api/courses/[slug]` (or `GET /api/lesson/[lessonId]`)
→ Select lesson: identify `lesson.filePath`, `lesson.type == "VIDEO"`, and `lesson.progress.position`
→ Video playback: construct `{BASE_URL}/api/files/{Uri.encodeFull(lesson.filePath)}` and play with video player
→ Update playback position periodically: `POST /api/progress` with `{ lessonId, courseId, moduleId, position, completed }`

## 9. Required Headers / Cookies

* **Authorization Headers:** NONE required.
* **Cookies:** NONE required.
* **Origin / Referer Headers:** NONE required (not verified by backend).
* **For Media Requests:** Standard `Range: bytes={start}-{end}` header (automatically generated by standard video player libraries).
* **For Progress POST:** `Content-Type: application/json`.

## 10. Required Backend Changes

- **Item 1: Add `GET` endpoint for `/api/courses/[slug]`**
  - **Status:** REQUIRED (for clean direct navigation from course card to course lesson tree)
  - **Reason:** In the web application, `app/course/[slug]/page.tsx` is a Server Component querying Prisma directly on the server, so `/api/courses/[slug]` only implemented `PATCH` and `DELETE`. Without this endpoint, the course list (`/api/courses`) only gives module/lesson *counts*, not lesson IDs, meaning the client cannot immediately call `/api/lesson/[lessonId]` unless a lesson ID is already known.
  - **Smallest Safe Change:** Add an `export async function GET(request, { params })` in `app/api/courses/[slug]/route.ts` that queries `prisma.course.findFirst({ where: { slug, hidden: false }, include: { modules: { include: { lessons: true } } } })` and returns JSON. This is an additive 15-line handler with zero side effects on existing code.

- **Item 2: CORS Header Support for Web/Local Debugging**
  - **Status:** NONE (for native Android APK / Windows `.exe`), OPTIONAL for Flutter Web
  - **Reason:** Native mobile and desktop Flutter apps do not enforce browser CORS restrictions.

## 11. Native Client Compatibility

Server Connection: READY
Authentication: READY
Courses: READY
Lessons: READY
Video Playback: READY

*Summary:* The existing backend architecture is 100% compatible with native Android and Windows clients. Standard REST JSON endpoints provide data, and HTTP 206 streaming provides seeking video playback.

## 12. Flutter Packages Actually Needed

Only the following minimal packages are required for the target functionality:
1. `http` (or `dio`): For standard REST API calls (`/api/courses`, `/api/lesson/*`, `/api/progress`).
2. `media_kit` + `media_kit_video`:
   - High-performance, cross-platform video player based on `libmpv`.
   - Native support for both **Android** and **Windows** out-of-the-box.
   - Robust support for HTTP byte-range streaming, seeking, and codec compatibility (supports `.mp4`, `.mkv`, `.webm`, `.avi`, `.mov` without transcoding).
3. (Alternative: `video_player` + `video_player_win`): Feasible, but `media_kit` is the industry standard for cross-platform desktop (Windows) + mobile (Android) video support.

## 13. Risks / Unknowns

1. **Local Network Android Cleartext (HTTP) Restriction:**
   - *Risk:* Android 9+ blocks unencrypted `http://` traffic by default.
   - *Mitigation:* Android Flutter app must configure `android:usesCleartextTraffic="true"` in `android/app/src/main/AndroidManifest.xml` or configure network security config to connect to LAN IP addresses (e.g. `http://192.168.x.x:6969`).
2. **Video Codec Compatibility on Client Device:**
   - *Risk:* Course libraries can contain MKV, HEVC/H.265, or 10-bit video files that standard mobile platform decoders may fail to decode.
   - *Mitigation:* Using `media_kit` (backed by FFmpeg/mpv) eliminates codec compatibility issues on both Android and Windows.
3. **URL Special Characters and Spaces in Video Paths:**
   - *Risk:* Course folder names and file names often contain spaces, parentheses, brackets, or Unicode characters.
   - *Mitigation:* Client must use `Uri.encodeFull` or encode path segments properly before making the media request.

## 14. Source Files That Matter Most

1. `app/api/files/[...path]/route.ts`: Controls video and media file streaming; implements HTTP 206 byte-range seeking and MIME detection.
2. `app/api/courses/route.ts`: Controls course list retrieval, pagination, filtering, and sorting.
3. `app/api/lesson/[lessonId]/route.ts`: Returns lesson details, file path, and complete course module/lesson tree.
4. `app/api/progress/route.ts`: Controls playback position persistence and resume points.
5. `app/api/courses/[slug]/route.ts`: Currently handles course edits; target location for adding `GET` course details.
6. `prisma/schema.prisma`: Defines the single-user SQLite database schema (`Course`, `Module`, `Lesson`, `Progress`).
7. `docker-compose.yml`: Defines the runtime ports (`6969:6767`) and volume mount mappings for `My_Courses` and `prisma_data`.

## 15. Final Verdict

Can we currently build a Flutter Android + Windows client that connects to this OfflineAcademy instance and plays its existing videos without redesigning the backend?

**YES WITH SMALL CHANGES**

### Concise Architectural Rationale:
1. **No Backend Redesign Required:** OfflineAcademy already operates as an HTTP server exposing JSON APIs and standard HTTP media streaming.
2. **Zero Auth Friction:** Authentication is nonexistent by design; no login flows, token refreshes, or credential storage are needed.
3. **True HTTP Range Streaming Exists:** The `/api/files/[...path]` route natively handles `Range: bytes=` headers, returns `206 Partial Content`, and streams via Node streams, enabling smooth video scrubbing and seeking.
4. **Clean Relative Path System:** The database stores `Lesson.filePath` relative to the courses root; appending this to `/api/files/` directly yields the playback URL.
5. **Course Catalog API is Ready:** `/api/courses` provides complete metadata, pagination, and course-level progress.
6. **Lesson API is Ready:** `/api/lesson/[lessonId]` provides complete lesson metadata, video format, duration, and progress position.
7. **Progress Persistence is Ready:** `POST /api/progress` allows seamless syncing of playback timestamps and completion state.
8. **Only One Small Backend Addition Needed:** Adding a standard `GET` handler to `app/api/courses/[slug]/route.ts` so the client can retrieve the module/lesson tree directly when a user selects a course from the catalog.
9. **Native Desktop & Mobile Ready:** `media_kit` in Flutter natively handles the required HTTP 206 stream and all video container formats on both Android and Windows.
10. **Docker Deployment Intact:** The standard Docker container on port `6969` exposes all necessary routes to LAN clients with no container modifications.
