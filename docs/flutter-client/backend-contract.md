# OfflineAcademy Technical Discovery & Backend Contract

## 1. Executive Summary & Context

This document details the technical discovery of the OfflineAcademy installation. OfflineAcademy is an offline-first, LAN-focused, single-user video course management and playback application.

All findings in this document are derived directly from the source code, Docker deployment manifests, and database schema in this repository.

---

## 2. System Architecture & Component Interactions

OfflineAcademy is implemented as a unified full-stack application using Next.js 14 with the App Router. There is no separate backend service or gateway; the Next.js server serves both the React client frontend and the JSON / media streaming HTTP API endpoints from the same process and port.

### 2.1 Technology Stack

* **Full-stack Framework:** Next.js 14.2.0 (React 18.3.0, TypeScript 5.4.0)
  * *Source:* [`package.json`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/package.json#L32)
* **Backend Runtime:** Node.js 22 (Debian Bookworm slim container) running Next.js Standalone server (`node server.js`)
  * *Source:* [`Dockerfile`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/Dockerfile#L44-L79)
* **Database & ORM:** SQLite via Prisma ORM 5.12.0
  * *Source:* [`prisma/schema.prisma`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/prisma/schema.prisma#L8-L11), [`lib/prisma.ts`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/lib/prisma.ts)
* **Media Serving:** Node.js `fs.createReadStream` supporting HTTP 206 Partial Content range requests
  * *Source:* [`app/api/files/[...path]/route.ts`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/app/api/files/%5B...path%5D/route.ts#L100-L133)

### 2.2 Actual Running Architecture Diagram

```text
+-----------------------------------------------------------------------------+
|                               Client Layer                                  |
|  [Web Browser / PWA]                 [Flutter Android / Windows Client]     |
+------------------------------------+----------------------------------------+
                                     |
                          HTTP / REST / Byte Ranges
                                     |
                                     v
+-----------------------------------------------------------------------------+
|                Docker Container: "offlineacademy" (:6767)                   |
|                Host Port Mapping: 0.0.0.0:6969 -> 6767                      |
|                                                                             |
|  +-----------------------------------------------------------------------+  |
|  |                Next.js Standalone HTTP Server (Node 22)               |  |
|  |                                                                       |  |
|  |  +---------------------------+   +---------------------------------+  |  |
|  |  |      API Route Handlers   |   |   Static & Media Stream Handler |  |  |
|  |  |   /api/courses            |   |   /api/files/[...path]          |  |  |
|  |  |   /api/lesson/[lessonId]  |   |   (HTTP 206 Range Streaming)    |  |  |
|  |  |   /api/progress           |   +----------------+----------------+  |  |
|  |  +-------------+-------------+                    |                   |  |
|  +----------------|----------------------------------|-------------------+  |
+-------------------|----------------------------------|----------------------+
                    | Prisma ORM                       | Node fs Stream
                    v                                  v
+------------------------------------+ +--------------------------------------+
|  Persistent Volume: prisma_data/   | |  Persistent Volume: My_Courses/      |
|  Mounted at /app/prisma/data/      | |  Mounted at /app/My_Courses/         |
|  File: dev.db (SQLite)             | |  Files: Course folders & .mp4 files  |
+------------------------------------+ +--------------------------------------+
```

---

## 3. Docker & Deployment Architecture

* **Container Name:** `offlineacademy`
* **Docker Compose Files:**
  * Local Build: [`docker-compose.yml`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/docker-compose.yml)
  * Docker Hub Image: [`docker-compose.hub.yml`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/docker-compose.hub.yml) (Image: `nicetry247/offlineacademy:latest`)
* **Port Mapping:**
  * Host Port: `6969`
  * Internal Container Port: `6767` (`PORT=6767`, `HOSTNAME=0.0.0.0`)
* **Mounted Volumes:**
  * `./My_Courses:/app/My_Courses` (Course media folder on host)
  * `./prisma_data:/app/prisma/data` (Directory housing the persistent SQLite database `dev.db`)
* **Entrypoint & Initialization:**
  * [`docker-entrypoint.sh`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/docker-entrypoint.sh) checks permissions and runs `gosu nextjs:nodejs ./node_modules/.bin/prisma db push --schema=/app/prisma/schema.prisma --skip-generate` on startup before booting `node server.js`.
* **Environment Variables:**
  * `PORT=6767`
  * `HOSTNAME=0.0.0.0`
  * `DATABASE_URL=file:/app/prisma/data/dev.db`
  * `COURSES_ROOT=/app/My_Courses`
  * `NEXT_PUBLIC_APP_URL=http://localhost:6969`
  * `QUIZAPI_KEY=` (optional)

### 3.1 Network Addresses for Native Clients

* **Local Machine (Windows Client on same host):** `http://localhost:6969` or `http://127.0.0.1:6969`
* **Local LAN (Android device or other Windows PC on same Wi-Fi/LAN):** `http://<HOST_LAN_IP>:6969` (e.g., `http://192.168.1.50:6969`)
* **Android Emulator (Standard Android Studio Emulator):** `http://10.0.2.2:6969`
* **Behind Reverse Proxy (e.g., Caddy/Nginx with TLS):** `https://academy.lan` or `https://academy.yourdomain.com`

---

## 4. Authentication Discovery

* **Authentication System:** **NONE**.
* **Evidence:**
  * No Next.js middleware file exists in the repository (verified: 0 matches for `middleware.ts`/`middleware.js`).
  * In the database schema ([`prisma/schema.prisma`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/prisma/schema.prisma#L101)), all user actions, progress records, quiz attempts, and bookmarks default to a static hardcoded user ID:
    ```prisma
    userId String @default("local-user")
    ```
  * In API handlers ([`app/api/progress/route.ts`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/app/api/progress/route.ts#L28), [`app/api/courses/route.ts`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/app/api/courses/route.ts#L49), [`app/api/lesson/[lessonId]/route.ts`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/app/api/lesson/%5BlessonId%5D/route.ts#L19)), queries explicitly hardcode `where: { userId: 'local-user' }`.
  * No JWT tokens, session cookies, Authorization headers, Bearer tokens, or CSRF checks are validated on any route.
  * Media streaming ([`app/api/files/[...path]/route.ts`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/app/api/files/%5B...path%5D/route.ts)) performs only a directory-traversal boundary check against `COURSES_ROOT` and requires zero credentials.
* **Verdict:** Authentication is **completely absent by design** for single-user local/LAN operation. A native client needs zero authentication headers, tokens, or login calls.

---

## 5. Course Data Model & Entity Relationships

The data models are defined in [`prisma/schema.prisma`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/prisma/schema.prisma).

### 5.1 Entity Diagram

```text
+-----------------------------------------------------------------+
| Course                                                          |
| - id: String (cuid)                                             |
| - name: String (folder name)                                    |
| - displayName: String?                                          |
| - slug: String (unique)                                         |
| - path: String (unique, absolute path on disk)                  |
| - thumbnail: String?                                            |
| - description: String?                                          |
| - hidden: Boolean (default false)                               |
| - favorited: Boolean (default false)                            |
+-------------------------------+---------------------------------+
                                | 1:N
                                v
+-----------------------------------------------------------------+
| Module                                                          |
| - id: String (cuid)                                             |
| - name: String (subfolder name)                                 |
| - slug: String                                                  |
| - order: Int                                                    |
| - courseId: String                                              |
+-------------------------------+---------------------------------+
                                | 1:N
                                v
+-----------------------------------------------------------------+
| Lesson                                                          |
| - id: String (cuid)                                             |
| - title: String (filename without ext)                          |
| - slug: String                                                  |
| - order: Int                                                    |
| - moduleId: String                                              |
| - filePath: String (relative to COURSES_ROOT, forward slashes)  |
| - fileName: String (e.g. "01 - Intro.mp4")                      |
| - mimeType: String (e.g. "video/mp4")                           |
| - duration: Int? (seconds)                                      |
| - thumbnail: String?                                            |
| - type: String ("VIDEO", "AUDIO", "PDF", "MARKDOWN", etc.)      |
| - subtitlePath: String?                                         |
+-------------------------------+---------------------------------+
                                | 1:N
                                v
+-----------------------------------------------------------------+
| SubtitleTrack (optional)                                        |
| - id: String                                                    |
| - lessonId: String                                              |
| - src: String (relative path e.g. "Course/Mod/01.vtt")          |
| - lang: String (e.g. "en")                                      |
| - label: String                                                 |
| - format: String                                                |
| - isDefault: Boolean                                            |
+-----------------------------------------------------------------+
```

### 5.2 Relationship with Progress Model

Each `Course`, `Module`, and `Lesson` links to `Progress`:
* `userId`: String (defaults to `"local-user"`)
* `position`: Int (playback seconds)
* `completed`: Boolean
* `lastWatched`: DateTime

---

## 6. Real API & Network Contract

All endpoints accept standard HTTP requests and respond with JSON (or binary media streams).

### 6.1 Server Health / Reachability Check
* **Method:** `GET`
* **Path:** `/api/settings` (or `/api/courses?limit=1`)
* **Auth Required:** No
* **Request Params:** None
* **Response Shape (200 OK):**
  ```json
  {
    "coursesRoot": "/app/My_Courses",
    "autoFetchQuizzes": "false",
    "quizApiSource": "quizapi",
    "quizApiKey": ""
  }
  ```
* **Purpose:** Lightweight JSON endpoint to verify network reachability and that the OfflineAcademy backend is responding.
* **Source:** [`app/api/settings/route.ts`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/app/api/settings/route.ts#L20-L53)

---

### 6.2 Retrieve Course List
* **Method:** `GET`
* **Path:** `/api/courses`
* **Auth Required:** No
* **Query Parameters:**
  * `page` (optional integer, default `1`)
  * `limit` (optional integer, default `10`, max `100`)
  * `search` (optional string, searches name, displayName, slug)
  * `filter` (optional string: `all`, `in-progress`, `completed`, `not-started`, `favorites`)
  * `sortBy` (optional string: `updatedAt`, `name`, `progress`, default `updatedAt`)
  * `sortOrder` (optional string: `asc`, `desc`, default `desc`)
* **Response Shape (200 OK):**
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
        "description": "Course overview",
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
* **Purpose:** Retrieve paginated course catalog.
* **Source:** [`app/api/courses/route.ts`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/app/api/courses/route.ts#L7-L161)

---

### 6.3 Retrieve Course Details, Modules & Lesson Tree
* **Method:** `GET`
* **Path:** `/api/lesson/[lessonId]`
* **Auth Required:** No
* **Query Parameters:** None (optional `?course=<slug>` accepted but not required)
* **Response Shape (200 OK):**
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
* **Crucial Architectural Finding Regarding Course Details:**
  * The web frontend's course page (`/course/[slug]`) is a Next.js **Server Component** that queries Prisma directly on the server rather than exposing an `/api/courses/[slug]` GET endpoint.
  * In contrast, `/api/courses/[slug]` implements only `PATCH` (rename/favorite/tag) and `DELETE`.
  * **However**, `/api/lesson/[lessonId]` returns the **entire course hierarchy** (including all modules, all lessons in each module, progress, next/previous navigation pointers, and stats) along with the requested lesson!
  * Furthermore, `/api/progress?type=continue` returns recent lessons and their parent course modules.
  * Therefore, a native client can fetch any lesson in a course to obtain the entire module and lesson tree for that course without needing a new course-details endpoint.
* **Source:** [`app/api/lesson/[lessonId]/route.ts`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/app/api/lesson/%5BlessonId%5D/route.ts#L4-L130)

---

### 6.4 Save Playback Progress
* **Method:** `POST`
* **Path:** `/api/progress`
* **Auth Required:** No
* **Headers:** `Content-Type: application/json`
* **Request Body:**
  ```json
  {
    "lessonId": "clesson123",
    "courseId": "ccourse123",
    "moduleId": "cmod123",
    "position": 150,
    "completed": false
  }
  ```
* **Response Shape (200 OK):**
  ```json
  {
    "success": true,
    "progress": {
      "id": "cprog123",
      "userId": "local-user",
      "courseId": "ccourse123",
      "moduleId": "cmod123",
      "lessonId": "clesson123",
      "position": 150,
      "completed": false,
      "lastWatched": "2026-09-14T13:45:00.000Z"
    }
  }
  ```
* **Purpose:** Save video playback position and completion status.
* **Source:** [`app/api/progress/route.ts`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/app/api/progress/route.ts#L14-L99)

---

### 6.5 Media & Video Streaming Route
* **Method:** `GET`
* **Path:** `/api/files/{filePath}` (e.g. `/api/files/Test Course/Module 1/01 - Introduction.mp4`)
* **Auth Required:** No
* **Request Headers:**
  * Standard `Range: bytes={start}-{end}` (e.g., `bytes=0-` or `bytes=1048576-2097151`)
* **Response Headers & Status:**
  * Status: `206 Partial Content` (for range requests) or `200 OK` (full file)
  * `Accept-Ranges: bytes`
  * `Content-Range: bytes {start}-{end}/{totalBytes}`
  * `Content-Type: video/mp4` (or `video/webm`, `video/x-matroska`, etc.)
  * `Content-Length: {chunkSize}`
  * `Content-Disposition: attachment; filename="{filename}"` (or `inline` for text/pdf)
* **Response Body:** Binary media byte stream.
* **Source:** [`app/api/files/[...path]/route.ts`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/app/api/files/%5B...path%5D/route.ts#L8-L158)

---

## 7. Video / Media Deep Dive

### 7.1 Storage and Database Path Mechanics

1. **Host Disk Location:** Files reside in the mounted host directory (e.g., `./My_Courses/Test Course/Module 1/01 - Introduction.mp4`).
2. **Container Disk Location:** Mapped directly to `/app/My_Courses/Test Course/Module 1/01 - Introduction.mp4` via volume mount.
3. **Database Storage (`Lesson.filePath`):** The scanner records the path **relative to `COURSES_ROOT`** with normalized forward slashes:
   * *Formula in Code:*
     ```typescript
     relativePath = relative(coursesRoot, join(modulePath, file.name)).replace(/\\/g, '/')
     ```
   * *Actual Database Value:* `"Test Course/Module 1/01 - Introduction.mp4"`
   * *Source:* [`lib/scanner.ts`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/lib/scanner.ts#L611)
4. **URL Construction:** The client prepends `/api/files/`:
   * *Web client implementation:*
     ```typescript
     src={'/api/files/' + lesson.filePath}
     ```
   * *Full URL for Flutter client:*
     `http://<SERVER_IP>:6969/api/files/` + `Uri.encodeFull(lesson.filePath)`
   * *Source:* [`app/watch/[lessonId]/WatchPageClient.tsx`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/app/watch/%5BlessonId%5D/WatchPageClient.tsx#L155)

### 7.2 HTTP Range Requests & Seeking Verification

In [`app/api/files/[...path]/route.ts`](file:///c:/Users/Dex/Documents/Dev/offlineacademyapp/app/api/files/%5B...path%5D/route.ts#L100-L133):
* Range header parsing:
  ```typescript
  const parts = range.replace(/bytes=/, '').split('-')
  const start = parseInt(parts[0], 10)
  const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1
  const chunkSize = end - start + 1
  ```
* Bounds checking: Returns `416 Range Not Satisfiable` if `start >= fileSize`.
* Stream generation: `createReadStream(actualPath, { start, end })`.
* Response: Status `206 Partial Content` with `Content-Range`, `Accept-Ranges: bytes`, `Content-Length: chunkSize`, and proper video MIME types (`video/mp4`, `video/webm`, `video/x-matroska`, `video/quicktime`, etc.).

**Verification:** Native video players (ExoPlayer on Android, LibVLC / Media Foundation on Windows) require HTTP 206 Partial Content with `Accept-Ranges: bytes` to perform scrubbing/seeking without downloading the entire video file first. The existing `/api/files/[...path]` endpoint **fully implements this specification**.

---

## 8. Native Client Compatibility Analysis

| Capability | Status | Evidence & Explanation |
| :--- | :---: | :--- |
| **Connect to server** | **READY** | Standard HTTP/1.1 endpoint on host port 6969. Android and Windows HTTP clients connect directly. |
| **Authenticate if required** | **READY** | No authentication exists. No tokens, cookies, or headers needed. |
| **List courses** | **READY** | `/api/courses` returns clean JSON with full pagination, tags, and progress. |
| **Open course / List lessons** | **READY** | `/api/lesson/[lessonId]` returns the entire course tree, modules, lessons, and stats. In addition, continuing progress returns course modules. |
| **Open lesson** | **READY** | `/api/lesson/[lessonId]` returns lesson details, `filePath`, `type`, `mimeType`, and saved position. |
| **Stream / play video** | **READY** | `/api/files/{filePath}` provides direct HTTP 206 partial content streaming with range requests. |

---

## 9. Potential Blockers & Edge Cases Evaluated

1. **URL Encoding with Spaces and Special Characters:**
   * *Scenario:* Lesson file paths frequently contain spaces and dashes (e.g. `Test Course/Module 1/01 - Introduction.mp4`).
   * *Resolution:* Standard URL path encoding must be applied in Flutter (`Uri.encodeFull`). Next.js's catch-all route `[...path]` handles URI-decoded path segments cleanly.
2. **Missing `GET /api/courses/[slug]` Endpoint:**
   * *Scenario:* The web UI renders `/course/[slug]` via a React Server Component querying the database directly rather than through an API endpoint.
   * *Impact on Flutter:* A Flutter client can retrieve course content using `/api/lesson/[lessonId]`. However, if a user clicks on a course from the course list without having watched a lesson yet, how does the client get the first lesson ID?
   * *Investigation:* The course list (`/api/courses`) returns `_count: { modules, lessons }`, but not the module or lesson IDs.
   * *Client-side options:*
     * Option A (Zero backend changes): When a user taps a course, the client calls `/api/progress?type=continue` or fetches the course tree. But if a course has 0 progress, its lesson IDs are not in `/api/courses`.
     * Option B (Clean & Minimal): Add a simple `GET` handler to `app/api/courses/[slug]/route.ts` that returns the course with modules and lessons (exactly what `app/course/[slug]/page.tsx` already does).
     * Option C (Workaround without backend changes): Alternatively, the client could fetch `/api/progress` or scan. However, adding `GET` to `/api/courses/[slug]/route.ts` is a 15-line standard Next.js addition.

---

## 10. Conclusion

The OfflineAcademy backend is exceptionally clean, lightweight, and almost entirely ready for a native Flutter client. Video playback over HTTP 206, unauthenticated access, and SQLite-backed REST routes provide everything required for native Android and Windows playback.
