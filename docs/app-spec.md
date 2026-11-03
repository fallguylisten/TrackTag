# TrackTag: app spec (draft, Nov 2026)

App name: TrackTag (formerly "Music Tagger"). Native macOS app (SwiftUI). Apple Music is the source of truth for tags; the app reads via iTunesLibrary and writes through Music (ScriptingBridge/AppleScript), then verifies the file tags (see Library I/O). The only local state is a small review-status file (see Queue). Master tag list: "Tag Dictionary" Claude Doc (https://claude.ai/artifact/LLEqxDbCttJPSPeCFitKNn). Mockups: "TrackTag Mockups" Design canvas. The user decides when the design is ready to build; don't announce readiness.

## Pipeline (user-defined)
1. Songs come in: not yet tagged by the app. First boot = whole library (migration first); afterwards = newly added songs. New files arrive via Music's "Automatically Add to Music" folder (copied into the media folder) or as LQ rips imported by MediaHuman (left in place in ~/Music/Crate/LQ/LQ YY:M).
2. Songs are tagged one category at a time, by click or keyboard hotkey; arrow keys write tags and move between songs.

## Queue rules (user-defined)
- Running list: tracks from the migration that haven't been reviewed stay in the queue across boots until reviewed; nothing drops off on its own.
- On every boot: pull the 10 tracks whose **Music Date Modified** is OLDEST, excluding long-form mixes (Grouping = MIX), for re-appraisal. Decision (Nov 2): use Music's date, not a TrackTag-only date — any save (tagging or Clean Up) counts as touched. Untagged pulls are not written, so they stay oldest and come back next boot.
- Local review-status file keyed by Apple Music persistent ID (reviewed yes/no, date, queue reason), because migrated tracks already look tagged.
- "Why it's here" reasons: New import · Re-check tags ({REVIEW} in the title) · Re-appraise (oldest modified) · Not reviewed yet (from migration) · Incomplete. {REVIEW} means the tags need another look, not a new file; saving the track in Tag removes {REVIEW}.

## Navigation and shared UI
- Tab bar centred in the header: **Settings | Review Queue ‹ Library › Tag Queue › Tag**. Library is the main tab (rounded outline pill, centred); Review Queue is the separate workflow on the left; arrows show the flow. Settings is the leftmost tab (gear icon, neutral grey; a thin divider separates it from the workflow tabs). Settings pages (Nov 3, split as-is): 1. **Files** — Apple Music library/media folder/organized check; Sources (RIP, DL); Storage (replaced & deleted folders, before bulk changes, change history). 2. **Library** — leave out MIX; default columns; Scanning (new tracks, background when idle, Rescan, Show unreadable). 3. **Tag Queue** — Needs tags when (+ re-appraise N oldest per launch). 4. **Tags** — tag editor. 5. **Review Queue** — Needs review when (always: title {!flags!}; Poor quality, sub-option only if Energy 3+ or in a gig playlist; fake lossless WAV < 21.5 kHz; DL graded only OK (off); file at risk: Trash, Downloads or missing); sound grades. (User removed the After-a-replace card.) Nov 3: sound grades split by file type, two grades (Good/Poor) each: each cut-off set with a slider (14–23 kHz). Defaults to catch truly bad files: MP3 Poor below 17.0 kHz (128 kbps or worse; 460 of 1,399), WAV Poor below 20.0 kHz (made from 256 kbps or worse; 4 of 162). Earlier ~300 kbps targets would be MP3 19.8 (785) / WAV 21.5 (18). Needs review toggles: MP3 graded Poor (+ only if Energy 3+ or gig playlist), WAV graded Poor, file at risk. The DL-graded-OK option was dropped (no OK grade). Tag Queue also always includes tracks not reviewed since the migration. Earlier layout, for reference: Settings pages (Nov 2): 1. **Files and Library** — Library: the library Music has open (no picker), media folder, check that “Keep organized” is off, leave out MIX. Sources: MediaHuman rips (RIP, ~/Music/Crate/LQ; MediaHuman adds to Music itself, a fixed note, not a switch; watch for replacements) and Artist downloads (DL, ~/Music/Crate/HQ with year folders 2025, 2026; TrackTag watches only this folder, never ~/Downloads; copy new tracks to Automatically Add, never replacements). No CD source: CDQ retired (tracktag-cdq-split.js: Good ceiling → DL/HQ, else RIP/LQ). DJ apps: after a replace, remind Rekordbox Relocate / Serato rescan, copy new file location. Safety: Replaced and Deleted folders + keep-for; before every bulk change save an undo file and export the library list (undo replays old values through Music); change history with Undo. 2. **Tags** — category/tag editor. 3. **Review** — sound grades (Good ≥ 19.5, Poor < 17.5 kHz, colour scale); Needs review when (Poor, fake lossless < 21.5 kHz, DL/CDQ graded OK (off), file at risk); Needs tags when (new, {REVIEW}, under 50% of categories, no album art) + re-appraise N oldest per launch; scanning.
- Inactive tabs are neutral grey with a small colour dot; only the active tab fills with its colour.
- Consistency rules (from the Nov 2 design critique): every page header = title matching the tab name + grey count + an (i) help tooltip; a toolbar row below with search then filter chips; selected-song details in a right-hand panel; one solid primary button per screen in its workflow colour, everything else outlined; vocabulary fixed to Review Queue / Library / Tag Queue / Tag.
- Workflow colours: orange = Library and general UI; teal = tagging (Tag Queue, Tag, "In tag queue", tagged %); red = review/replacement (Review Queue tab, {!reason!} flags).
- Font: Helvetica throughout.
- Every tab has the same footer player bar (play/pause, art, title/artist, waveform scrubber, times, "Double-click a song to play · Space play/pause"). The player is global: switching tabs keeps the same song and position. Window content is fixed-height; lists and panels scroll so the player is always visible.

## Tabs
1. **Library** (main): every track (minus mixes). Search, filters (All / Reviewed / In tag queue / Replace), Columns menu (show/hide + drag to reorder: Art, Title, Artist, Genre, Stars·energy, Comments, Date added, Tagged % of 17 categories, Status, BPM, Remixer, Quality, Released, Last modified). Above the player: a selection bar — red-tinted "‹ Send to Replace" on the left, the selected song in the middle, teal-tinted "Send to Tag Queue ›" on the right (normal rounded buttons; the chevron shows direction).
2. **Tag Queue**: condensed list (#, title, artist, BPM, added, why it's here); no tags shown. Right panel: Selected track (art + Change art), then "Field Edit": Clean Up button; Title; Version with a small "original" checkbox (auto-ticked when Clean Up finds no version); Comments {notes/flags}; Artists; Remixer; Quality; Release Date; separate Before and After boxes (current file name vs edited name); Revert / Save fields; "Start tagging →".
3. **Tag**: one song at a time. Header: art, title/version/artists/BPM/year, and the current tags as small centred pills. Left: categories (↑↓). Centre: tag pills sized by usage with letter keys, "+ Add a tag", tag filter search, Comments preview. Right: narrow Energy LED meter panel (levels 1–5 Sitting/Chilling/Moving/Dancing/Peaking; green 1–3, orange 4, red 5; current level shown bold next to the "Energy" heading); writes Rating. Key hints above the player.
4. **Review Queue** (renamed from Replace): same layout as Tag Queue — header "Review Queue · N songs", search + filter chips (All / Replace / Review / File at risk), condensed list (#, title, artist, quality, flagged date, why it's here), right panel with the selected track, note-to-self, Open in Tag / Clear flag and a solid red "Mark replaced". Library's left button is "‹ Send to Review Queue"; Library status "In review".
5. **Settings** (gear): categories and hierarchy; add, rename, merge tags (rewrites the library); definitions; pinned letter keys.

## Library I/O (validated against the Mac, Nov 2 2026)
Observed:
- Library: ~/Music/Music/Music Library.musiclibrary; media folder ~/Music/Music/Media.localized/Music, organised Artist/Album/Title. ~1,371 library tracks live there (1,208 MP3, 163 WAV in the export). ~190 MediaHuman LQ tracks are referenced in place in ~/Music/Crate/LQ/LQ YY:M; a handful elsewhere (DJ Mixes, Full Albums, My Songz, Friend Music, Archive).
- "Keep Music Media folder organized" is OFF (confirmed by the user; the Artist/Album/Title layout is left over from when it was on). Tag and name edits change tags only; files stay where they are, so Rekordbox/Serato paths don't break. Serato cue/beatgrid data also lives inside the files (GEOB frames), which the write path must preserve.
- All 1,581 library files under ~/Music exist on disk (26 differ only in letter case, which macOS ignores).
- MP3s are ID3 v2.3 (most) and v2.4. Media-folder WAVs (187 of 188) already carry an ID3 chunk whose Comments match the library, so file tags are currently in sync.
- Current Comments use " . " as the delimiter (1,523 tracks), not pipes — the migration rewrites every comment string, so smart-playlist rules must be converted in the same step.
- 3 library tracks point into ~/.Trash and 1 into ~/Downloads (will break when emptied/cleaned) → surface in Replace as "file at risk".
- "Automatically Add to Music" is empty apart from its Not Added folder (two cover images Music rejected).
Write path:
1. Write the changed fields through Music (only fields that changed).
2. Read the file's tags back; if a WAV (or any file) doesn't match, patch its ID3 directly, preserving all other frames (especially Serato GEOB frames and artwork).
3. Log old/new values per track for undo; back up the library before the first write; batch operations (migration, bulk Clean Up) show a preview and write only on confirm.
Smart playlists: see claude/smart-playlists.md — rules must be converted in the same step as the Comments migration.

## Category behaviours on the Tag tab (decided Nov 2)
Mockups 3b–3e show the patterns.
- Pick one: Version (always set; suggested from the title, Return keeps it), Decade. A letter picks it and jumps to the next category.
- Pick at least one: Family (1–2), Mood. Category list shows an amber "!" until met. Leaving the song (→) is still allowed; the song is saved and stays in the Tag Queue as "Incomplete".
- Pick any or none: Style, Sound, Reaction, Structure, Audience, Language, Rhythm, Dance, Theme, Instruments. Letters toggle; ↓ moves on.
- Child adds parent: Place (country adds region, marked "auto-added"), Style (style adds family; Club-group styles add Club).
- Conditional: Reference (~) only opens for Flip, Mashup or Megamix.
- Free text: Note // with autocomplete from earlier notes (with song counts); Return on an empty field saves and moves to the next song.
- Era: pre-filled from the release year for Original versions; picked by hand for remixes/edits/flips.
- ↓ always steps through every category in order (no auto-skipping of rarely used ones).
- Suggestions (dashed outline) come from tag pairings in the library, e.g. Jersey + Diva → Party / Playful / Sexy; they are never written unless picked.

## Categories (decided Nov 2; Comments tag names unchanged)
Tagging stops, in order: Genre (was Family) · Subgenre (Style) · Mood (+ Lyrics tags Couples, Slut, Political) · Version (+ Original Sample ~ sources, shown under the cards for Flip/Mashup/Megamix) · Decade (Era) · Texture (Sound + Instruments & vox, incl. Instrumental/Acapella; Acid and Dub live here) · Crowd reaction (Reaction + Moves: Ass, Sucio, Whine, LineDance) · Beat & Structure (Rhythm + Structure) · Audience · Place · Language · Note. 12 stops.
Energy panel: the 1–5 meter plus a "Set" row with Opener / Closer toggles (replaces the When to play category; the Peak tag was dropped because every Peak track was Energy 5).
Merges are app-side groupings only, so smart playlists keep working.

## Tag tab: category behaviours (decided Nov 2)
- Pick one: Version (always set; suggested from the title, Return keeps it), Decade (pre-filled from the release year for Originals; picked by hand for remixes/edits/flips). A letter picks the option AND moves straight to the next category.
- Pick at least one: Family (1–2), Mood (≥1). Category list shows an amber "!" until met. Moving to the next song with none picked is allowed; the song stays in the Tag Queue as "Incomplete".
- Pick any or none (letters toggle, ↓ moves on): Style, Sound, Reaction, Structure, Audience, Language, Rhythm, Dance, Theme, Instruments.
- Picking a child adds its parent: Place (country → region, shown "auto-added"), Style (→ family; Club group auto-adds Club).
- Conditional: Reference ~ only opens for Flip / Mashup / Megamix; otherwise shown greyed.
- Free text: Note // with autocomplete from earlier notes (with song counts); each entry is a removable pill; Return on an empty field saves and goes to the next song.
- ↓ always steps through every category (no auto-skipping).
- Every tag category ends with a dashed "+ Add a tag" button (Version: "Add a version type", Place: "Add a place").
- Suggestions (dashed outline) come from tags that usually appear together, e.g. Jersey + Diva → Party, Playful, Sexy.
- Mockups: 3b Version, 3c Mood, 3d Place, 3e Note.

## Category display names (decided Nov 2)
Shown in the app (Comments tags themselves are unchanged): Energy (the Rating field; shown as level + name, no stars) · Genre (was Family) · Subgenre (was Style) · Version · Original Sample (was Reference ~) · Decade (was Era) · Language · Beat (was Rhythm) · Texture (was Sound) · Instruments & vox (was Instruments) · Structure · Mood · Set position · Reaction · Dance · Audience · Place · Theme · Note. Still to decide: Structure, Set position, Reaction, Dance, Audience, Place, Theme, Note.

## Quality check (spectrogram)
- On first open (and optionally a background library scan) the app decodes the file (AVFoundation), runs an FFT (Accelerate) and finds the "sound ceiling" — the highest frequency with real content. Lossless ≈ 22 kHz · 320 ≈ 20 · 192 ≈ 19 · 128 ≈ 16. Cached per track.
- Review Queue: "Quality mismatch" reason/chip for WAVs under ~21.5 kHz and HQ/CDQ files under ~18.5 kHz; Bitrate column is plain grey (bitrate doesn't predict sound); only the Ceiling column is coloured: red when below what the format promises (MP3 < 19.5 kHz, WAV < 21.5 kHz), green otherwise; selected-track panel shows the spectrogram with the ceiling line and a one-line verdict. Library: optional "Sound ceiling" column.
- First scan (Nov 2): 20 HQ/CDQ tracks sound low (incl. 2 fake WAVs); 337 LQ rips actually sound ~320+. Report: ~/Music/TrackTag/quality-report.csv.
- Grouping = where the file came from, not how it sounds: RIP (MediaHuman rip, was LQ) / DL (artist download from Bandcamp/SoundCloud, was HQ) / CDQ (CD rip, was CDR). tracktag-grouping.js renames them. Sound quality is a separate measured grade from the ceiling: Good ≥ 19.5 kHz · OK 17.5–19.5 · Poor < 17.5. 44% of 320 kbps rips are Poor because the source upload was low.

## Replace flow (Review Queue)
- Review Queue reasons: Poor quality (measured sound grade Poor, < 17.5 kHz) · Has unexpected sounds (DJ tags, drops, glitches) · Clean/explicit swap · File at risk. Replacement only: {REVIEW} tracks go to the Tag Queue (Re-check tags). Each is a filter chip. Sorted by importance (energy, play count, playlist/gig-set membership). Sound grades: Good ≥ 19.5 kHz · OK 17.5–19.5 · Poor < 17.5.
- Keyboard on both queue tabs: ↑ ↓ previous / next track · Return = start tagging (Tag Queue) or replace when a file is found (Review Queue) · Space play/pause · ⌘F search.
- Never drop a replacement into "Automatically Add to Music" (that makes a duplicate track).
- TrackTag watches Downloads and Crate/HQ; a new audio file is matched to a queued track on artist, title and length → "Replacement found" in the side panel: Current vs New (source, format, ceiling, sound grade, length), two spectrograms with play buttons, offset warning if the new file starts later/earlier, list of what is kept. Manual fallback: drop a file on the track. Buttons: Not a match / Replace ⏎.
- Replace: file the download into Crate/HQ/<year>; copy into the Music media folder; relink the SAME Music track to the new file (keeps persistent ID, tags, energy, title, artwork, plays, playlists, date added); write tags + artwork into the new file (preserving Serato frames is moot: new file); Quality → DL; remove {REPLACE}; re-run quality check; move the old file to ~/Music/TrackTag/Replaced (30 days); show Undo.
- DJ apps: Rekordbox shows the track as missing → Relocate (cues kept, may be offset); Serato: rescan, cues must be re-set. "Copy new file location" button.
- To verify on the Mac: Music accepts relinking a track to a different format (MP3 → WAV). Fallback: add new track, copy every field/rating/plays/artwork, add to the same playlists, remove the old entry (date added is lost).
- Mockups: "Replace 1 · better copy found in Downloads", "Replace 2 · replaced, same track".

## Flags, sources, Library energy (Nov 2)
- Title syntax: replacement flags are {!reason!}: {!poor quality!}, {!unexpected sounds!}, {!explicit!} / {!clean!}. {REVIEW} = re-check tags (Tag Queue reason, not a replacement). Old Genre=REVIEW (8) / Genre=REPLACE (4) flags were overwritten by the migration; longtail.json restores them into titles as {REVIEW} / {!replace!}. Annotations like {108 > 127} unchanged. Searchable in Rekordbox/Serato. No note-to-self field in Review Queue.
- Settings → Sources (new section; Settings nav: Tags · Sources · Library · Quality · Shortcuts): one card per source with folder, type badge, toggles. MediaHuman rips (RIP, ~/Music/Crate/LQ, adds tracks to Music by itself, watched for replacements; most better copies arrive here at 320 kbps). Artist downloads (DL, ~/Downloads, filed into ~/Music/Crate/HQ/{year}, new tracks copied to "Automatically Add to Music", watched). CD rips (CDQ). Replaced files folder + keep-for (30 days default).
- Replace when the better copy comes from MediaHuman: MediaHuman has already added it to Music as a second track, so Replace relinks the original track to the new file and removes the duplicate entry.
- Library: Energy column shows just the number in a box coloured by level (1–3 green, 4 orange, 5 red). Library has the same shortcut bar (↑↓, ⇧↑↓ select several, Return tag this track, Space, ⌘F).
- Side panel label is "Spectrogram". Repeated helper text removed across tabs.
- Library "Next step" column (replaces Status), colour-coded pill: Needs review (red) if the track has a {!reason!} flag, a Poor sound grade or a file at risk; otherwise Needs tags (teal) if it's new, {REVIEW}, unreviewed from the migration or under 50% of the 12 categories, or has no album art; otherwise "—". Review beats tagging. Filters: All / Needs review / Needs tags / Nothing to do. Tagged % is a plain number (no bar). Default Library columns: Art · Title · Artist · Genre · BPM · Tags (Comments) · Added · Tagged · Next step; hidden by default: Energy, Remixer, Source, Sound ceiling, Released, Last modified, Plays.
- Spectrogram is taller: 220px in the Review Queue panel, 132px each in the Replace comparison.
- List tables (Library, Tag Queue, Review Queue) share one header style: sticky header row, 11px uppercase grey labels, 8px/14px header padding, 6px/14px row padding, 36px first column (# or art), and a small Columns icon button in its own 24px column at the right end of the header (opens the show/reorder pop-up, closed by default).
- Nov 2: the 8 old Genre=REVIEW tracks were marked for deletion (tracktag-delete.js + delete.json: removes them from Music, moves files to ~/Music/TrackTag/Deleted). The 4 Genre=REPLACE tracks get {!replace!} via restore-flags.json.

## Album art
- From each track's artwork in Music (~1,364 of 1,585 had art; ~220 none). Change art lives in the Tag Queue panel: drop/paste an image or "Find artwork" (iTunes Search API; for edits/flips offer the original's cover). Written through Music and embedded in the file.

## Tag page controls (user-defined)
- ← / →: previous / next song (tags written on leaving). ↑ / ↓: previous / next category.
- 1–5: energy level (Rating). Letter keys: toggle tags (letters assigned by usage). Space: play/pause. Clicking the tag search focuses it (hotkeys pause). Click works for everything.

## Category order and chip sizing
- Categories by usage: Family, Style, Mood, Set position, Version, Era, Sound, Reaction, Structure, Audience, Place, Language, Rhythm, Reference, Dance, Theme, Instruments. Tags within a category by usage. Not every song needs every category.
- Style follows Family and shows that family's styles, larger = more used. Frequencies recalibrated from the library on every boot.

## Comments format
`| Tag | Tag | ... | // free text`
- Tags between pipes in fixed category order; smart rules match `| Tag |`.
- Free-text note after `//`: Rare, people, sampled artists. App autocompletes note words.
- Source references (`~RnB`, `~Pop`, ...) stay as tags; same rule for every family.

## Title / artist / composer / genre format (user-defined)
- Title: name with parentheses that are part of the name kept: `Be (Show Me Love)`. Version in square brackets: `Bikini [Gaszia Edit]`. Notes and flags in braces at the end: `{108 > 127}`, `{REVIEW}`, `{!poor quality!}`.
- Artist: all artists, comma-separated (`Lil Jon, Usher`); ft./;/·/x → commas; `&` left alone.
- Composer: the remixer(s).
- Genre: main style only (family when no style). Grouping: quality LQ/HQ/CDQ. Long-form mixes (Grouping = MIX) excluded.

## Version (single-select, always set)
Original · Edit · Remix · Flip · Mashup (2–3) · Megamix (4+) · DJ Tool. Sampled moved to Sound.

## Decisions
- Mood: multi-select, at least one per track.
- No Vocals, Bass or Vocal-type categories. No LowVox. No PopVox.
- BPM: don't double half-tempo values. No Mixed In Key.
- No new smart-playlist crates for now.
- UMM NO LYRICS PLZ = Electronic AND NOT vocal-heavy tags/families AND NOT ~source, OR Instrumental.
- SKY SURFING = Floating OR Ethereal OR Spacey OR Synthy.
- Club = cross-family group (Jersey, MiamiBass, Gqom, Dembow, Bubbling, Baltimore, Bounce, GhettoTech, Kuduro, LiteFeet).

## Review Queue side panel (Nov 3)
Per selected track, top to bottom: track header · Spectrogram (shorter, 130px) with verdict · Flag dropdown (Poor quality / Has unexpected sounds / Clean/explicit swap / File at risk, + Add custom flag…, No flag = leave the queue) · Replacement found panel when a match exists (Current vs New table, two small spectrograms with play, merge note, what's kept; Not a match / Find another…) · Find replacement… (file browser, picks a file to compare) · Make replacement (primary; disabled until a file is chosen) · Delete from library… (destructive, at the bottom).
After Make replacement: the track shows "Replaced · leaves at end of session" in the list and drops out of the queue when TrackTag closes; selection jumps to the next track automatically, with a "replaced · Undo" banner. The "In your DJ apps" section was removed.

## Button shortcuts (Nov 3)
Every button with a shortcut shows a small keycap after its label (same style everywhere). Review Queue: Make replacement ⏎ · Not a match N · Find replacement/another ⌘O · Delete from library ⌘⌫. Library: Send to Review Queue ⌘← · Send to Tag Queue ⌘→. Tag Queue: Clean Up ⌘K · Revert ⌘Z · Save fields ⌘S · Start tagging ⏎. Settings → Tags: Save to library ⌘S. Destructive actions (Delete from library, Retire) use red text/outline, never the filled primary style.
- Nov 3 decisions: Tag screen track counter lives in the track header on every Tag board; Settings has no shortcut bar; Settings page headers are title only; selected-track art is 48px in both queues.
- Library selection: checkbox column at the left of every row, select-all checkbox in the header (shows "–" when some are selected). Selection bar shows "N selected" with a Clear (esc) button. Shortcuts: ↑↓ move · ⇧↑↓ select several · ⌘-click add/remove · ⌘A select all · esc clear selection.

## Title annotation syntax (Nov 3, replaces {…})
- Personal annotations: `<text>` e.g. `HARDX <108 > 127>`. Shown everywhere.
- Review flags: `!text!` e.g. `King Kunta !poor quality!`, `Ballin !review!` (was {!…!} / {REVIEW}). Written to the title in Music and the file tags (searchable in Rekordbox/Serato), but TrackTag hides them in its own title displays and shows the flag only in the "Why it's here" / Next step columns. Files are not renamed (Keep organized is off), so annotations don't appear in file names.
- tracktag-syntax.js converts existing titles ({!x!}→!x!, {REVIEW}→!review!, {x}→<x>), with undo. Run after longtail.json / restore-flags.json, which still write the old form.
- Review side panel actions (Find/Make replacement/Delete, Not a match) are pinned to the bottom of the panel.

## Replace: verified (Nov 3)
Relinking a Music track from an MP3 to a WAV works and keeps the same track (ID, comment, rating, plays, playlists). Done with AppleScript `set location`; JXA can't. Writes right after adding a file can briefly fail (-54) while Music imports it, so retry.
