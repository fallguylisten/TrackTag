# TrackTag

A native macOS app (SwiftUI) for tagging an Apple Music library for DJing. Apple Music is the source of truth; Rekordbox, Serato and VirtualDJ read from it.

## Run it
1. Install Xcode from the Mac App Store.
2. Open this folder in Xcode (File → Open… → `TrackTag`). Xcode reads `Package.swift`.
3. Choose the **TrackTag** scheme and **My Mac**, then Run (⌘R).
4. The first time it writes, macOS asks to let TrackTag control Music — allow it.

## Layout
- `Sources/TrackTagCore` — pure logic: Comments tags, title syntax (`<note>`, `!flag!`), sound grades, Next step rules. Tests in `Tests/`.
- `Sources/TrackTag` — the app: screens, reading the library (iTunesLibrary), writing through Music (JavaScript for Automation).
- `docs/` — app spec and smart-playlist plan.
- `scripts/` — the one-off migration scripts already run on the library (kept as a reference for how writes go through Music).

## Rules
- Never edit audio files or Music's database directly. Write through Music, then read back.
- Long mixes (Grouping = MIX) are excluded.
- Every bulk change saves an undo file first.
