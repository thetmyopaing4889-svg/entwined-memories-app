---
name: GitHub push remote
description: Workspace GitHub pushes may use a nonstandard remote name that the helper cannot auto-detect.
---

When the repository has a GitHub remote named something other than `origin`, the managed push helper may report `NO_REMOTE` even though a valid GitHub remote exists. Verify remote names first; use the secure workspace credential flow or an authenticated direct push without exposing token values.

**Why:** The project remote was named `github`, so the helper's `origin` lookup failed even though the repository was correctly connected.

**How to apply:** Never print or persist credentials. Confirm the remote branch after pushing and inspect the resulting GitHub Actions run.