---
name: YouTube processing status
description: OAuth scope and polling requirements for the Entwined Memories YouTube upload flow.
---

The YouTube refresh token used by the Worker must include both upload and read access. Upload can succeed with `youtube.upload` alone, but `videos.list` status/processing lookups require a token with `youtube.readonly` as well.

**Why:** A token that successfully uploads can still make status polling fail with Google's `insufficientPermissions` response, leaving the app's processing label stuck.

**How to apply:** Keep OAuth refresh and status lookup behind the Cloudflare Worker. Have the Flutter Home screen poll the Worker for processing memories, then update only the Firestore `processingStatus` field to `ready` or `failed`.