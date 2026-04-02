# sb_loadingscreen

Custom loading screen for SB Framework. Displays server branding, keybind reference, server rules, and a loading progress bar while players connect to the server.

## Features

- Background image slideshow with multiple images
- Optional background video support
- Scanline overlay effect
- Server branding with logo and tagline
- Quick controls reference sidebar (keybinds)
- Server rules display
- Ambient audio toggle
- Animated loading progress bar with percentage display
- Status text updates during loading phases
- Modern UI with Poppins and JetBrains Mono fonts
- Fade-in animations
- Manual shutdown (stays visible until multicharacter or game is ready)
- Cursor enabled during loading

## Dependencies

None. This is a standalone loading screen resource.

## Installation

1. Place `sb_loadingscreen` into your resources folder.
2. Add `ensure sb_loadingscreen` to your `server.cfg`. It should be ensured early, before most other resources.
3. Replace the background images in `html/` with your own:
   - `background.jpg`
   - `background2.jpg`
   - `background3.png`
4. Optionally provide a `loading_video.mp4` in `html/` for video background.

## Configuration

This resource has no Lua config file. All customization is done by editing the HTML/CSS/JS files in the `html/` folder:

- `html/index.html` - Layout, branding text, keybinds, server rules
- `html/style.css` - Colors, fonts, sizing, animations
- `html/script.js` - Slideshow timing, progress bar logic, audio behavior

Key things to customize:

- Server name and tagline in `index.html`
- Quick controls keybinds in the sidebar
- Server rules text
- Background images (replace the files in `html/`)
- Color scheme in `style.css`

## No MLO/Mapping Required

This is a purely UI-based resource with no in-game world elements.

## License

Written by Salah Eddine Boussettah for SB Framework.
