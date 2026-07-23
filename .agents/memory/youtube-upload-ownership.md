---
name: YouTube upload ownership
description: Where upload privacy and embeddability are controlled in Entwined Memories.
---

The Cloudflare Worker does not upload video bytes or set YouTube video metadata. Flutter obtains an access token from the Worker, then initializes the resumable YouTube upload and sends the `snippet` and `status` payload directly to YouTube.

**Why:** Changing only the Worker cannot correct upload privacy or embed settings; the actual upload payload must be changed in the Flutter YouTube service.

**How to apply:** Keep `privacyStatus: unlisted` and `embeddable: true` explicit in the Flutter upload metadata. Keep the Worker focused on OAuth token refresh and processing-status reads.