# Entwined Memories

## Project Architecture

Version: 2.0

This document is the technical source of truth.

Every developer must read this before writing code.

---

# 1. PROJECT TYPE

Entwined Memories is a private family memory application.

It is NOT a social network.

It is NOT a gallery.

It is NOT a cloud storage service.

It is a memory home.

---

# 2. DEVELOPMENT PHILOSOPHY

Emotion first.

Technology second.

Every technical decision must support the emotional experience.

Never sacrifice simplicity for unnecessary complexity.

---

# 3. TARGET USERS

Primary Users

• Father

• Mother

Secondary User

• Their child (many years later)

---

# 4. CURRENT PRODUCT SCOPE

Version 1 focuses on

ONE FAMILY ONLY.

This means

Father

Mother

One Child

Future multi-family support may be added later.

Do NOT over-engineer Version 1.

---

# 5. SYSTEM OVERVIEW

Flutter App

↓

Firestore (Memory Data)

↓

Cloudinary (Photos)

↓

Cloudflare Worker

↓

YouTube (Videos)

---

# 6. DATA STRUCTURE

Family

familyId

createdAt

updatedAt

---

Child

childId

name

birthday

profilePhoto

coverPhoto

createdAt

---

Parents

dadName

momName

---

Memory

memoryId

familyId

date

note

mood

imageUrl

videoId

createdBy

createdAt

updatedAt

---

Settings

theme

language

playbackPreference

---

# 7. FIRESTORE STRUCTURE

families

└── familyId

├── child

├── parents

├── settings

└── memories

      └── memoryId

There should never be global memories.

Everything belongs to one family.

---

# 8. STORAGE STRATEGY

Text

Firestore

Photos

Cloudinary

Videos

YouTube

Flutter only stores metadata.

Original media lives in external services.

---

# 9. VIDEO FLOW

User selects video

↓

Flutter

↓

Cloudflare Worker

↓

YouTube Upload

↓

Receive Video ID

↓

Save Video ID into Firestore

---

# 10. PHOTO FLOW

User selects photo

↓

Cloudinary Upload

↓

Receive URL

↓

Save URL into Firestore

---

# 11. MEMORY FLOW

Create Memory

↓

Upload media

↓

Receive URLs

↓

Save metadata

↓

Timeline updates automatically

---

# 12. HOME SCREEN STRUCTURE

Cover Photo

↓

Child Profile

↓

Age

↓

Statistics

↓

Timeline

↓

Floating Add Memory

---

# 13. ONBOARDING

Splash

↓

Welcome

↓

Create Child

↓

Parents

↓

Create Memory Home

↓

Timeline

---

# 14. PLAYBACK

Reads all memories

↓

Sort by date

↓

Slideshow

↓

Optional music

---

# 15. SECURITY

Version 1

Private Family

No public feed

No sharing

No advertisements

No tracking

---

# 16. UI PRINCIPLES

Warm

Minimal

Premium

Emotional

Apple-inspired

Lots of whitespace

Large photos

Soft shadows

Rounded corners

---

# 17. DEVELOPMENT RULES

Never redesign without approval.

Never change UI philosophy.

Never remove emotional elements.

Never replace architecture without discussion.

Every commit must preserve the Project Vision.

---

# 18. FUTURE FEATURES

AI Caption

Voice Memory

Memory Reminder

Memory Search

Memory Export

Photo Book

Family Tree

Timeline Video Export

---

# 19. VERSION 1 GOAL

The father opens the app.

Adds a memory.

The mother immediately sees it.

Years later,

their daughter opens the app

and smiles.

If this happens,

Version 1 is successful.

---

# 20. FINAL PRINCIPLE

Technology will become outdated.

Frameworks will change.

Programming languages will evolve.

But memories must remain.

Every architectural decision must protect memories first.
