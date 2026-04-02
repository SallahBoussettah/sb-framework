# sb_phone

iOS-style smartphone with a React UI featuring calls (pma-voice integration), messages, contacts, bank transfers, social media (Instapic), camera with photo upload, and a job app. Inventory-based - requires a phone item to use.

## Tech Stack

- **UI:** React, TypeScript, Tailwind CSS, Zustand (state management), Framer Motion (animations)
- **Backend:** Lua (FiveM client/server), oxmysql
- **Voice:** pma-voice (call channels)

## Features

### Phone Interface

- **Boot screen** - animated startup sequence
- **Lock screen** - Face ID cosmetic unlock animation (configurable, detects helmets)
- **Home screen** - iOS-style app grid with icons
- **Status bar** - in-game time, signal, battery indicators
- **Home indicator** - swipe gesture emulation
- **Peek overlay** - Dynamic Island-style call notification when phone is closed during active call
- Custom wallpapers
- In-vehicle and on-foot phone prop and animation sets
- NUI focus management with movement controls preserved

### Phone Calls (pma-voice)

- Dial by phone number via keypad or from contacts
- Incoming call Dynamic Island notification
- Call states: ringing, connected, missed, busy, unavailable
- Configurable call timeout (default: 30 seconds)
- Speaker mode toggle (state-bag synced)
- Phone minimizes during active call with peek overlay
- Call history tracking
- pma-voice channel integration for proximity-independent voice

### Messages (SMS)

- Threaded conversation view per contact
- Send and receive text messages
- Message delivery status tracking
- Max message length configurable (default: 256 characters)
- Offline message notification support

### Contacts

- Add, edit, delete contacts
- Favorite contacts
- Max contacts limit (default: 50)
- Quick dial and quick message from contact card

### Bank App

- View bank balance (integrated with sb_banking)
- Transfer money to other players by phone number
- Configurable min/max transfer amounts
- Transaction confirmation

### Social Media (Instapic)

- Instagram-style social feed
- Create posts with captions and photos
- Like and comment on posts
- User profiles with bio and username
- Follow/unfollow system
- Stories with image support
- Comment count tracking

### Camera

- In-game photo capture using FiveM screenshot API
- Front/back camera flip
- Flash toggle
- Landscape mode support
- Upload to configurable service (fivemanager, imgur, Discord webhook, or custom URL)
- Photos saved to gallery
- HUD controls overlay with keybind hints

### Gallery

- Browse captured photos
- View full-size images

### Job App

- View current job information

### Settings

- Change wallpaper
- Select ringtone (7 built-in: default, harp, apex, radar, sencha, silk, summit)
- Toggle airplane mode (disables calls/messages)
- Sound volume and keyboard sound toggle

### Sound System

- Custom sound effects for UI interactions
- Configurable ringtones with audio files
- Call sounds: ringing, busy, unavailable, invalid number
- Keyboard click sounds (toggleable)
- Volume control

### Phone Number System

- Formatted as (XXX) XXX-XXXX
- Configurable area code prefixes (555, 310, 213, 323, 818)
- Auto-generated on first phone activation
- Serial-based phone ownership (phone item metadata)

## Dependencies

- [oxmysql](https://github.com/overextended/oxmysql)
- sb_core
- sb_inventory (phone item with serial/metadata)
- sb_notify
- sb_banking (for bank app balance and transfers)
- pma-voice (for phone call voice channels)

## Installation

1. Ensure all dependencies are started before `sb_phone` in your `server.cfg`.
2. Place `sb_phone` in your resources folder.
3. Add `ensure sb_phone` to your `server.cfg`.
4. The script auto-creates all required database tables on first start (`phone_serials`, `phone_social_profiles`, `phone_social_follows`, `phone_social_comments`, and migrations on existing phone tables).
5. The phone item is auto-inserted into `sb_items` on startup.
6. Configure your screenshot upload service via server convars in `server.cfg`:
   ```
   set sb_phone_fivemanager_token "YOUR_TOKEN_HERE"
   set sb_phone_imgur_clientid "YOUR_CLIENT_ID"
   set sb_phone_discord_webhook "YOUR_WEBHOOK_URL"
   set sb_phone_custom_upload_url "YOUR_URL"
   ```
7. Players need a `phone` item in their inventory to use the phone. The phone opens with Arrow Up and closes with Arrow Down or Backspace.

## Configuration

All configuration is in `config.lua`:

- `Config.ItemName` - inventory item name (default: `'phone'`)
- `Config.Prop` / `Config.PropBone` - phone prop model and attachment bone
- `Config.MaxContacts` - max contacts per phone (default: 50)
- `Config.MaxMessageLength` - max SMS length (default: 256)
- `Config.MaxPostCaptionLength` - max social post caption (default: 200)
- `Config.MinTransfer` / `Config.MaxTransfer` - bank transfer limits
- `Config.CallTimeout` - seconds before unanswered call becomes missed (default: 30)
- `Config.SoundVolume` - default volume for UI sounds (default: 0.3)
- `Config.KeyboardSounds` - enable keyboard click sounds (default: true)
- `Config.CameraUploadMethod` - screenshot upload service (`'fivemanager'`, `'imgur'`, `'discord'`, `'custom'`)
- `Config.ScreenshotQuality` - JPEG quality for captures (default: 0.85)
- `Config.FaceIdEnabled` - enable Face ID unlock animation (default: true)
- `Config.PhoneNumber.Prefixes` - area code options for generated numbers
- `Config.Ringtones` - available ringtone filenames
- `Config.Anims` - animation dictionaries for on-foot and in-vehicle phone usage
- `Config.ObstructingHelmets` - helmet prop indices that block Face ID

## Exports

### Server

| Export | Description |
|--------|-------------|
| `createPhone(citizenid, name)` | Create a phone serial and assign to a citizen |

## Screenshots

Screenshots coming soon.
