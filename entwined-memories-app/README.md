# entwined-memories-app

📖 Read the Project Vision first:
PROJECT_VISION.md

Every contributor must read this document before making any code changes.
For My Baby
📱 Baby Memory App – COMPLETE MASTER DOCUMENT (FINAL)

---

1. 🎯 PROJECT PURPOSE

ဒီ app ကို မိဘများက သူတို့ကလေးအတွက်
📸 ပုံများ
🎥 video များ
📝 အမှတ်တရများ

ကို တစ်နေရာတည်းမှာ သိမ်းဆည်းပြီး timeline ပုံစံနဲ့ ပြန်ကြည့်နိုင်ရန် ဖန်တီးသည်။

👉 ဒီ app သည်

- Private (family only)
- Emotional (memory-focused)
- Long-term (years of memories)

ဖြစ်ရမည်။

---

2. 👶 APP TYPE (IMPORTANT)

❗ ဒီ app သည် fixed child app မဟုတ်ဘူး

👉 Generic App ဖြစ်ရမည်
👉 မည်သူမဆို သူ့ကလေးအတွက် သုံးနိုင်ရမည်

---

3. 🚀 FIRST TIME USER FLOW (ONBOARDING)

📌 App စဖွင့်ချိန်

Step 1: Login

- Google Login ဖြင့် ဝင်ရမည်

---

Step 2: Create Child Profile (VERY IMPORTANT)

👉 User ကို form ဖြည့်ခိုင်းမည်

Fields:

- 👶 Child Name
- 🎂 Birthday
- 📸 Profile Photo (optional but recommended)

---

Step 3: Create Family Space

- User သည် “Owner” ဖြစ်မည်
- Invite second user (Mom/Dad)

---

✅ RESULT:

User သည် သူ့ကလေးအတွက် private space တစ်ခုရရှိသည်

---

4. 🧠 CORE UX DESIGN

📜 MAIN STYLE = Facebook Timeline Style

- Vertical scroll
- New memory on top
- Old memory down
- Infinite scroll

---

5. 🏠 HOME SCREEN (TIMELINE)

🔝 Top Section

- Child profile photo
- Child name
- Age (auto calculate from birthday)

---

📜 Middle Section

👉 Memory Timeline Feed

Each item = Memory Card

---

➕ Floating Button

- Bottom right
- Add Memory

---

6. 🧩 MEMORY CARD (DETAILED)

📦 Each Card Contains:

- 📅 Date
- 📝 Note
- 📸 Image / 🎥 Video preview
- 😊 Mood (emoji)
- 👤 Created by (Dad / Mom)

---

🎨 Design:

- Rounded corners
- Soft shadow
- Clean layout

---

👆 Interaction:

- Tap → Detail View
- Long press → Edit / Delete

---

7. ➕ ADD MEMORY SYSTEM

📥 Input Fields:

- Date picker
- Note input
- Media upload (photo/video)
- Mood select

---

⚙️ Behavior:

- Save → timeline ထဲပေါ်
- Upload → loading show

---

8. 👁 MEMORY DETAIL VIEW

- Full image/video
- Full note
- Date
- Created by

---

9. 👨‍👩‍👧 FAMILY SYSTEM

Concept:

- 2 users share 1 child

---

Behavior:

- User A upload → User B sees instantly
- Shared data (same timeline)

---

10. 🔐 ACCESS CONTROL

- Only invited users can access
- No public sharing
- Private data

---

11. 🎬 MEMORY PLAYBACK (SPECIAL FEATURE)

Concept:

All memories → auto slideshow video

---

Behavior:

- Sort by date
- Show 3–5 sec per memory
- Full screen playback

---

UI:

- ▶️ Play Button

---

12. 🧭 NAVIGATION

Bottom Navigation:

- 🏠 Home
- 👶 Profile
- ▶️ Playback
- ⚙️ Settings

---

13. 👶 CHILD PROFILE SCREEN

Show:

- Name
- Birthday
- Age (auto)
- Profile photo

---

Edit:

- Editable

---

14. ⚙️ RULES & BEHAVIOR

- Memory edit ✅
- Memory delete ✅
- Delete = all users affected
- Upload limit (to define)
- Video compression needed

---

15. ☁️ BACKEND STRUCTURE

Firebase

- Auth → login
- Firestore → text data
- Storage → media

---

Data Structure:

Child:

- name
- birthday
- photo

---

Memory:

- date
- note
- media URL
- mood
- created by

---

Family:

- users list

---

16. 🔄 SYNC SYSTEM

- Real-time update
- No refresh needed

---

17. 🎨 UI STYLE

- Soft pastel colors
- Clean layout
- Emotional feel

---

18. 🎯 MVP DEFINITION

Must include:

- Onboarding (child info input)
- Timeline scroll
- Add memory
- Photo upload
- Cloud save
- Multi-user sync

---

19. 🚀 FUTURE FEATURES

- Voice memory
- AI caption
- Reminder
- Export video
- Print album

---

20. 🧠 PROJECT RULE

👉 ဒီ document = SOURCE OF TRUTH

- Developer follow this
- AI read this
- No confusion

---

21. 🏁 FINAL SUCCESS

👉 User creates child profile
👉 Upload memory
👉 Other user sees instantly
👉 Timeline smooth

= 🎉 SUCCESS

---

## 22. Long-Term Family Archive and Encrypted Backup

This private installation uses a single shared family account. Firebase, Cloudinary, Cloudflare R2, and YouTube are useful display or metadata services, but they are **not** the source of truth for the family archive. The original selected photos and videos are copied first into the Android Original Vault; deleting a Memory from the app does not delete those originals.

| Archive layer | Location | Purpose |
| --- | --- | --- |
| Original Vault | `Pictures/Entwined Memories Originals/` | Full-resolution photos and videos selected through the app. |
| Family Journal | `Documents/Entwined Memories Archive/Journal Events/` | Append-only local event history. |
| Portable export | `Documents/Entwined Memories Archive/Exports/` | CSV, JSON index, README, and integrity manifest. |
| Encrypted pack output | `Documents/Entwined Memories Archive/Encrypted Backups/` | Client-side encrypted `.emb` parts for manual secondary copies. |

### 22.1 Creating a complete encrypted snapshot

From **Settings**, choose **Encrypted Backup ဖန်တီးမယ်** whenever the family wants to make an off-site backup. The app asks for an archive passphrase of at least 16 characters and confirms it before beginning. The passphrase is used only for that operation: it is not saved in the app, Android settings, Firebase, TeraBox, Telegram, or the Journal.

On the first complete backup on each phone, Android asks the parent to select exactly `Pictures/Entwined Memories Originals`. The app persists access only to that selected Original Vault tree and its subfolders; it does not request broad gallery access or scan unrelated photos. This includes originals created on that phone and originals copied into the same vault by Syncthing-Fork.

Every snapshot is intentionally **standalone and complete**: it packages all current Original Vault photos and videos plus the complete Journal Events and Exports tree. This avoids a fragile incremental chain when parents manually upload to TeraBox or Dad-only Telegram. The app shows photo, video, Journal, and Export counts before an off-site copy can be marked complete.

It encrypts the ZIP stream with **AES-256-GCM** and derives its encryption key through **PBKDF2** with a random salt. Every archive file has a SHA-256 entry in the encrypted snapshot manifest. Very large snapshots are split into `.emb` parts named like `snapshot_..._part001.emb`, `snapshot_..._part002.emb`, and so on.

> **Recovery rule:** Every `.emb` part with the same `snapshot_...` ID is required. Keep their exact file names, keep them together, and never upload, download, or restore only one part from a multi-part snapshot. The newest verified complete snapshot can be restored by itself; no older snapshot chain is required.

### 22.2 Verify and restore before trusting an off-site copy

Use **Verify Latest Encrypted Backup** in Settings to decrypt and inspect the latest local complete snapshot. The app validates the AES-GCM authentication tag and verifies every file's SHA-256 value against the encrypted manifest. A wrong passphrase, missing part, altered part, or corrupt manifest must be treated as a failed verification.

Use **Restore encrypted .emb files** for a recovery drill or when restoring downloaded parts. First select the folder containing all `.emb` parts from one snapshot, then select a separate empty or new destination folder. The app creates a new `Entwined Memories Restore snapshot_...` folder and does not overwrite an existing restore folder or file. If authentication or manifest validation fails, the newly-created restore snapshot folder is removed. The restore feature writes recovered files into a safe restore destination; it does not automatically re-import them into the app timeline or overwrite the Original Vault.

### 22.3 Manual TeraBox and Dad-only Telegram copies

The app never asks for, saves, displays, or transmits TeraBox or Telegram credentials. Parents manually sign in to those services and upload **only** the encrypted `.emb` documents.

| Destination | Manual rule |
| --- | --- |
| TeraBox | Upload every part of the selected snapshot as files. Do not rename parts. Do not upload raw photos, raw videos, Journal folders, the passphrase, or any recovery note. |
| Dad-only Telegram private channel | Dad's account is the only member. Attach every `.emb` part as a **File/Document**, not as gallery media. Never send raw originals, the passphrase, recovery notes, or service login information. |

Keep the passphrase and recovery instructions on paper in a safe place known to both parents. A cloud copy without the passphrase cannot restore the archive; a passphrase shared in a cloud chat weakens the protection of every off-site copy.

### 22.4 Six-month health check

The **Family Backup Health** card in Settings is shared through `app_data/settings.backupHealth`, so Dad and Mom can see the latest snapshot's photo/video/Journal/Export counts, local verification, restore drill, TeraBox check, and Telegram check. It does not contain secrets. Completing a new encrypted snapshot clears checks that applied to the older snapshot and sets the next check six calendar months later.

Each phone can enable its own Android local reminder using **ဒီဖုန်းအတွက် ၆ လ Reminder ဖွင့်/Update လုပ်မယ်**. Notification permission is requested only from that explicit action. Android manufacturers may delay background alarms, so the in-app due card remains the required fallback; opening Settings shows the due state even if a phone notification was delayed.

### 22.5 Syncthing storage choice

The Journal Documents tree may be shared through Syncthing for Journal and export redundancy. Encrypted packs can be large and are intended for manual TeraBox and Dad-only Telegram copies, so the recommended default is to add this ignore rule to the **Journal** Syncthing folder on both phones:

```text
Encrypted Backups/**
```

This preserves the Journal and Exports sync without automatically consuming storage and transfer data for large encrypted parts. A family may deliberately omit this ignore rule if it wants every encrypted pack duplicated across both phones and has sufficient storage; that is a storage decision, not a replacement for the off-site copy and restore drill.

---
