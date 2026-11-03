# Smart playlists: current rules and post-migration plan (Nov 2 2026)

Validated against the Nov 2 library export: every current rule below reproduces Music's actual membership exactly (MIXUPS off by 1, case of "Beatswitch").
Counts = today → after migration with the new rule. Apply the new rules in the same step as the Comments migration (" . " delimiters → `| Tag |`).

| New # / name | Current rule | New rule | Today → new |
|---|---|---|---|
| #00 THE NEW NEW | Date Added in last 2 months | unchanged | 17 |
| #01 MY FAVES | Loved | unchanged | 103 |
| #02 ULTRA HQ | Bit Rate > 320 AND Grouping ≠ MIX | unchanged | 167 |
| #03 RARE CUTS | Comments contains "Rare" | unchanged (Rare moves to the `// note`; still matches) | 28 → 28 |
| #10 CHILL VIBES | "Chill" AND Rating ≠ 5★ | Rating 1–2★ (Sitting, Chilling); Chill tag retired | 453 → 619 |
| #11 THE BUILD | "Rising" | `\| Rising \|` | 26 → 30 |
| #12 GAME TIME | Rating = 3★ | Rating 3–4★ (Moving, Dancing) | 854 → 656 |
| #13 PEAKING | Rating = 5★ | unchanged | 303 |
| #14 CLOSING | Genre is "CLOSING" | `\| Closing \|` (Genre becomes main style) | 43 → 43 |
| #20 SKY SURFING | Ethereal OR Spacey OR Synthy | `\| Floating \|` OR `\| Ethereal \|` OR `\| Spacey \|` OR `\| Synthy \|` | 155 → 168 |
| #21 UMM NO LYRICS PLZ | "Electronic" | (`\| Electronic \|` AND NOT "~" AND NOT `\| Pop \|`/`\| RnB \|`/`\| HipHop \|`/`\| Soul \|`/`\| Diva \|`/`\| SingAlong \|`) OR `\| Instrumental \|` | 513 → 377 |
| #22 DARKROOM | "Dark" AND "Electronic" | `\| Dark \|` AND `\| Electronic \|` | 75 → 77 |
| #23 MIXUPS | Silly OR Fun OR BeatSwitch | `\| Silly \|` OR `\| Fun \|` OR `\| BeatSwitch \|` (old "Fun" also caught Funky/GFunk) | 282 → 228 |
| #24 SUMN 4 DA LADIES | " Girl ." OR " Diva ." | `\| Girl \|` OR `\| Diva \|` | 213 → 213 |
| #25 SUCIO | "Sucio" | `\| Sucio \|` | 37 → 40 |
| #26 DRY PLATINUM | "Lowrider" | `\| Lowrider \|` | 30 |
| #27 VAI VAI | Baile OR Carioca | `\| Baile \|` OR `\| Carioca \|` (~Baile flips excluded by the source rule) | 89 → 85 |
| remove: #: TESTING | "baile" AND added in last 4 months | — (temporary) | 9 |

Left alone: GIGS folder (set lists), @: AMRITS FAVES (regular playlist).

If the old rules are left in place after the migration: CHILL VIBES 453 → 0, SUMN 4 DA LADIES 213 → 0, GAME TIME 854 → 505.

Editing: Music's scripting can't create or edit smart-playlist rules, so TrackTag can't rewrite them directly. Options: edit by hand from this table (~15 min), or test whether Music accepts an imported playlist XML carrying smart criteria.

## Combo playlists (script-built, Nov 2 2026)
Built by ~/Music/TrackTag/tracktag-playlists.js as regular playlists in the folder "TT COMBOS", emptied and refilled on each run (Music can't create smart playlists from a script). TrackTag should rebuild them on launch / after tagging. Counts from the post-migration data:
01 WARM UP — Opening, or ★2 + Groovy/Soulful/Deep/Smooth (76) · 02 AFTER HOURS — ComeDown/Lounge, or Electronic ★1–2 (168) · 03 AFRO SUNSET — Amapiano/AfroHouse ★1–3 (54) · 04 DISCO HOUSE — Disco + House (40) · 05 AFROBEATS PARTY — Afrobeats ★3–5 (86) · 06 WEDDING SAFE — Classic/SingAlong ★3–4, no Sucio/Slut/Aggro/Evil (51) · 07 FLIPPED — ~Pop/~RnB/~HipHop sources in Electronic (48) · 08 GIRLS NIGHT — Girl/Diva ★4–5 (106) · 09 QUEER PEAK — Gay/Queer/Lesbian ★4–5, or Ballroom (41) · 10 CLUB BANGERS — Club ★4–5 (237) · 11 PERREO — Reggaeton/Dembow ★4–5, or Latin + Sucio/Ass (39) · 12 ISLAND HEAT — Caribbean ★4–5 (28) · 13 DESI (39) · 14 HIP HOP PEAK — HipHop ★5 (70) · 15 DARK PEAK — Dark/Evil Electronic ★4–5 (37).
