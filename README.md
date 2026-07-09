# entwined-memories-app
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
