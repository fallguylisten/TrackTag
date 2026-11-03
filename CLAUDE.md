# TrackTag — notes for Claude

- Design source of truth: the "TrackTag Mockups" Design canvas and `docs/app-spec.md` (also in the Music Tagger project).
- Writes go through Apple Music only (JXA via osascript, see `MusicWriter`). Never write files or the Music DB directly. Preserve Serato GEOB frames.
- Title syntax: `Name (part) [Version] <personal note> !review flag!`. Review flags are hidden in TrackTag's title displays and shown in "Why it's here" / Next step.
- Comments format: `| Tag | Tag | // note`; smart playlists match `| Tag |`.
- Grouping = source (RIP / DL). MIX tracks are excluded everywhere.
- Sound grades: MP3 Poor below 17.0 kHz, WAV Poor below 20.0 kHz (user-adjustable).
- Build order: library I/O → MP3→WAV relink test → Library, Tag Queue, Tag, Review Queue, Settings.
- The user can't see this sandbox: anything they need goes in the repo or the reply.
