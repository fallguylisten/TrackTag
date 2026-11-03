# TrackTag — notes for Claude

- Design source of truth: the "TrackTag Mockups" Design canvas and `docs/app-spec.md` (also in the Music Tagger project).
- Writes go through Apple Music only (JXA via osascript, see `MusicWriter`). Never write files or the Music DB directly. Preserve Serato GEOB frames.
- Title syntax: `Name (part) [Version] <personal note> !review flag!`. Review flags are hidden in TrackTag's title displays and shown in "Why it's here" / Next step.
- Comments format: `| Tag | Tag | // note`; smart playlists match `| Tag |`.
- Grouping = source (RIP / DL). MIX tracks are excluded everywhere.
- Sound grades: MP3 Poor below 17.0 kHz, WAV Poor below 20.0 kHz (user-adjustable).
- Build order: library I/O (done) → MP3→WAV relink test (passed) → Library, Tag Queue, Tag, Review Queue, Settings.
- The user can't see this sandbox: anything they need goes in the repo or the reply.
- Relink test PASSED (Nov 3): Music can point an existing track at a different file, MP3 → WAV, keeping persistent ID, comment, rating, play count and playlists. Use AppleScript for this (`set location of (first track of library playlist 1 whose persistent ID is "…") to POSIX file "…"`); the JXA form fails with "Can't get object". So Replace = relink the same track, no copy-fields fallback needed.
- After Music adds a file, it may still be importing: writes fail with -54 "File permission error" for a moment. Wait and retry.
