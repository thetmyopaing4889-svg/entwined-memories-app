---
name: YouTube WebView Error 153
description: The Android WebView configuration required by the Entwined Memories in-app YouTube player.
---

YouTube may reject an Android WebView embed with Error 153 when the player request cannot identify a valid embedding page. The player request should include YouTube `Referer` and `Origin` headers and matching `enablejsapi=1` plus `origin` URL parameters.

**Why:** The video can be uploaded, processed, and playable on YouTube while the in-app embed still fails before playback because the WebView request lacks player identity metadata.

**How to apply:** Keep playback inside the app's WebView, centralize the embed request so initial load and user-triggered reload use the same headers/query parameters, and retain an in-app retry/fallback state.