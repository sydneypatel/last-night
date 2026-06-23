<div align="center">

# last night.

** capture the night, relive it tomorrow. **

*a group photo app for the moments you'll want to remember — revealed all at once, to relive all the best memories!*

</div>

---

## 🌅 overview

**Last Night** is a social photo app built around a simple idea: when you're out with friends, you capture the night — but nobody sees the photos until they unlock the next morning. No real-time feed, no chasing the perfect shot, no checking your phone. Just everyone capturing their own view of the night, revealed together at sunrise.

Each group decides when its photos unlock — the next morning at **sunrise**, after a weekend on **Sunday night**, or at a **custom time** — and until then, everything stays sealed. The next morning, the whole night spills out at once.

---

## ✨ features

| Feature | Description |
|---------|-------------|
| 🌄 **Locked photos** | Photos stay hidden until the group's unlock time — sunrise, Sunday night, or custom |
| 👯 **Groups** | Create a group, invite friends, and capture the same night from everyone's eyes |
| 🔗 **Deep-Link Invites** | Share a link that opens straight into the app and joins the group |
| 📸 **Capture Mode** | A clean, distraction-free camera built for the night |
| 🖼️ **Library** | Save your favorite unlocked photos to a personal library |
| 📌 **Featured Grid** | Pin your top 9 photos to your profile |
| 🔔 **Smart Notifications** | Get notified when photos unlock, friends join, or someone follows you |
| 🔒 **Private by Design** | Your nights stay between you and your group |

---

## 🧠 tech stack

### 📱 Frontend
- **SwiftUI** — native iOS, built in Xcode
- **Firebase Auth** — Google & Apple Sign-In
- **AVFoundation** — custom camera capture
- **Universal Links** — deep-link invites that open the app

### ⚙️ backend
- **Node.js + Express** — REST API on **AWS EC2** (managed with `pm2`)
- **PostgreSQL** — hosted on **AWS RDS**
- **Firebase Cloud Messaging** — push notifications

### ☁️ infrastructure
- **Amazon S3 Bucket** — photo storage with presigned upload URLs
- **CloudFront** — CDN for fast photo delivery
- **AWS Lambda** — scheduled "sunrise unlock" job that flips photos and fires notifications
- **EventBridge** — triggers the unlock Lambda on a schedule
- **Netlify** — landing page + invite link previews

---

## 🏗️ architecture

```
                          ┌─────────────────-┐
                          │   iOS App        │
                          │   (SwiftUI)      │
                          └────────┬─────────┘
                                   │
                 ┌─────────────────┼─────────────────┐
                 │                 │                 │
                 ▼                 ▼                 ▼
        ┌────────────────┐ ┌──────────────┐ ┌────────────────┐
        │ Express API    │ │  Firebase    │ │  S3 (presigned │
        │  on EC2 (pm2)  │ │  Auth + FCM  │ │   uploads)     │
        └───────┬────────┘ └──────────────┘ └───────┬────────┘
                │                                    │
                ▼                                    ▼
        ┌────────────────┐                  ┌────────────────┐
        │  PostgreSQL    │                  │  CloudFront    │
        │   on RDS       │                  │   (CDN)        │
        └────────────────┘                  └────────────────┘

        ┌───────────────────────────────-───────────────────┐
        │  Scheduled Unlock Pipeline                        │
        │                                                   │
        │  EventBridge  ──▶  Lambda  ──▶  flips photos      │
        │   (schedule)      (unlock)      + sends FCM push  │
        └──────────────────────────-────────────────────────┘
```

**How the unlock works:** When a group is created, its unlock time is stored in Postgres. A scheduled **Lambda** runs on an **EventBridge** trigger, scans for groups whose unlock time has passed, flips their photos from locked → unlocked, and fires a **push notification** to every member: *"last night's photos just unlocked! 📸"*

**How invites work:** Each group has a shareable link (`last-night-app.com/join/CODE`). On a device with the app installed, **Universal Links** intercept the URL and open straight into the group. Without the app, the link lands on a **Netlify**-hosted page with a preview and a download button.

---

## 🎨 design

Minimal, monochrome, and built for nighttime — a black canvas, clean type, and nothing that gets in the way of the moment.

---

## 🤸‍♀️ made by

Built and created by **Sydney** & **Katie** 🌙

---

<div align="center">

</div>