---
name: YouTube playback reliability
description: Why Entwined Memories avoids WebView playback for reliable YouTube playback.
---

YouTube may reject Android WebView embeds with Error 153, 152-4, or a “Sign in to confirm you're not a bot” challenge. Valid app referrer/origin metadata can address identity errors, but it cannot make server-side anti-bot decisions reliable, especially on VPN or flagged shared IP addresses. The app therefore opens the normal YouTube watch URL through Android's official YouTube app or browser rather than embedding playback in WebView.

**Why:** Official YouTube clients and full browser sessions have YouTube's supported cookies, account flow, and client signals. A WebView can display the player but still be blocked by YouTube's server-side verification; changing headers or User-Agent values cannot guarantee playback and can make the client less trustworthy.

**How to apply:** Launch `https://www.youtube.com/watch?v=<videoId>` with an external application launch mode. Keep a user-facing fallback for devices without a YouTube app/browser, and tell users to disable VPN when YouTube itself is blocking the network identity.