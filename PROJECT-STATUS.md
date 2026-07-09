# Site Survey Annotation Tool — Project Status

**Last updated:** July 9, 2026 (cloud library + project-first workflow live)
**Live site:** https://site-survey-measure.netlify.app
**Deliverable:** a single standalone HTML file (no dependencies, no build step). In this repo it is **`index.html`** so it loads at the bare domain.
**Purpose:** Browser-based tool for marking up site survey photos for graphics installs — draw measurement lines, label dimensions, add text notes, and export annotated files (PDF / PNG / SVG) that clients can approve directly, without a designer as intermediary.

---

## Hosting & how updates work

- Hosted on **Netlify**, auto-deployed from this **GitHub repo**. Commit a change to `index.html` and Netlify republishes in a minute or two.
- The owner (Ryan) is **not a developer**. Historically updates were manual copy-paste over `index.html` in the GitHub web UI; the project is now transitioning to **Claude Code** (via the Claude mobile app on iPad, cloud-based, connected to this repo) making edits and commits directly.
- Ryan tests on the **live Netlify site** using a Samsung Galaxy Fold 7 and an iPad; a colleague uses an iPhone; another colleague uses an **older iPad** (important for compatibility — see July 9 fixes).

## Non-negotiable constraints (read before changing anything)

1. **Single HTML file, zero external dependencies.** No frameworks, no build step, no npm. All prior attempts with React/JSX failed in delivery. The one narrow exception: the HEIC converter (see below) is lazy-loaded from a CDN **only** at the moment a photo can't be decoded natively — it is never loaded otherwise.
2. **Exported files ARE the save state.** All three export formats (PDF/PNG/SVG) carry embedded base64-encoded JSON project data (`SSA1:` marker) so any saved file can be reopened in the tool to restore the full editable session. Never break this round-trip.
3. **Mobile reliability on iOS AND Android (Samsung) is a top priority.** Platform quirks require explicit handling; regressions here are the most damaging kind.
4. **Plain-language communication.** Ryan makes decisions quickly when tradeoffs are framed without jargon; explain technical choices with analogies.
5. **Iterative delivery.** One validated feature at a time. Test logic in isolation before integrating.

---

## Current feature set (all working & live)

**Loading**
- "Load photo": native file/photo picker (accepts images plus `.svg`/`.pdf` for reopening saved projects).
- "Camera": native camera on phones; in-app live viewfinder on desktop https.
- Reopening: the load handler auto-detects PDF/SVG/PNG files made by this tool and restores the full editable project from the embedded data; other images load as a fresh photo.
- **HEIC support (added July 9, 2026):** photos are first tried natively (newer Apple devices decode HEIC themselves). If decode fails and the file is HEIC, a converter (heic2any) is fetched from jsdelivr on the fly, the photo is converted to JPEG, and loading proceeds. Status bar shows "Converting HEIC photo…" during conversion. Requires internet at that moment (fine — the tool is a website).

**Annotation**
- Measurement lines with draggable endpoints; five end styles (arrowhead, chevron, dot, tick, none) in three sizes; line weight thin/med/thick.
- Per-line labels in movable bubbles with dashed leader lines to the line; standalone text labels; independent text and bubble-fill colors; per-item label size (slider or corner drag handle).
- Pinch-zoom / pan via SVG viewBox; floating +/−/fit buttons; tap targets scale with zoom.
- Undo (covers all mutations), delete, clear.

**Saving / export**
- **Title field** in the toolbar — drives download filenames and PDF metadata.
- **Save dropdown** with three formats, all carrying embedded editable data:
  - **PDF** — print-ready page; the primary client-facing deliverable
  - **PNG** — flat image at native photo resolution; quick to view or text
  - **SVG** — editable vector; opens in Illustrator (the designer escape hatch)

**Mobile UI**
- Full-screen canvas with a slide-in properties drawer (auto-opens on draw/select; ⚙ Edit reopens; ✓ Done commits and closes).
- Samsung keyboard fixes (input/composition events, 16px input, no autofocus on touch); iOS-safe hidden file inputs; synchronous picker calls.

---

## July 9, 2026 fixes (in this version — verify on an OLDER iPad)

1. **iPad file picker wouldn't open.** On iPadOS the file picker is a popover that must anchor to the input element. The hidden inputs were clipped to zero size a pixel offscreen, so the popover silently failed (iPhone/Android use full-screen sheets and were unaffected; newer iPads tolerate it). Fix: `.hiddenfile` is now `position:fixed` at screen center, 1×1px, opacity 0, `pointer-events:none`.
2. **HEIC photos from the Files app failed on devices without native HEIC decode** (older iPads, Android). Fix: lazy CDN fallback converter described above. Routing: `hu()` tags HEIC files → `loadImageSrc(src, heicFile)` → on `im.onerror`, `convertHeic()` loads heic2any and retries as JPEG.

**Testing status:** JS syntax validated; behavior on Ryan's newer iPad confirmed working (it worked even pre-fix due to native HEIC + tolerant popover). The real test is the **colleague's older iPad** — confirm (a) the picker opens, and (b) a HEIC from Files loads after the "Converting…" message.

---

## Key technical notes

- Vanilla JS + SVG live canvas; `<canvas>` composites the PNG export. Single state object `S`; annotations live in `S.lines` (`type:'text'` marks standalone text).
- **Zoom is via the SVG `viewBox`** (`S.vb`). Pointer→image conversion MUST include the viewBox origin (`v.x + …`) — omitting it caused the historical "drag jumps when zoomed" bug.
- Embedded project data: exported files contain `SSA1:<base64 JSON>`; `extractPDFData` / `extractSVGData` / `extractPNGData` find it and `restoreProject()` rebuilds the session.
- Mobile drawer scrim ignores clicks for 450ms after opening (`S.drawerAt`).
- File inputs: keep picker `.click()` synchronous from the user tap (iOS requirement) and never `display:none` the inputs.

## Known limitations

- No scale calibration — measurements are typed by hand (panel shows px length/angle for reference).
- Photo-based auto-measurement from a reference dimension was assessed: workable on straight-on shots, unreliable (~5–20% error) on angled/perspective photos. Not built.

---

## Roadmap (agreed order)

1. **Supabase cloud project library** — `projects` table (job folders) + `walls` table (annotated photos) + Storage bucket for photo files (photos in storage, only pointer URLs in table rows). Save flow gains "Save locally" (existing) vs "Save to a project". Three phases: backend setup → save flow → browse library. **Local-first stays the default** — cloud is opt-in (resolves confidentiality for external users). **STATUS (July 9, 2026): the full client is built and live in `index.html`** — see "Cloud library" below. It stays dormant until the two Supabase keys are pasted into the config block at the top of the `<script>`. Remaining: paste keys, run the schema SQL, live-test the round-trip.
2. **Authentication / login gate** — library launches open-access, login added as near-term follow-up.
3. **Multi-page PDF export** — bundle all walls of a job into one packet, matching the company's existing install-deck format (a sample deck PDF exists as reference).
4. **PWA installability**; in-app camera (lower priority).

## Cloud library (Supabase) — how it's wired (added July 9, 2026)

- **Zero-dependency**: talks to Supabase via plain `fetch` against the REST + Storage HTTP APIs. No SDK, no CDN — the single-file guarantee holds.
- **Config**: two constants (`SUPABASE_URL`, `SUPABASE_KEY`) in a labelled banner at the top of the `<script>`. Blank by default → cloud buttons show a friendly "not switched on yet" note and every local feature is untouched. `cloudReady()` gates all cloud code.
- **UI entry points**: ☁ **Library** button in the toolbar and an "Open from a project" button on the drop zone (both open the browse modal); **Save → Save to a project** row in the save dropdown (opens the save modal). One shared modal (`#cloudmodal`).
- **Data model**: `projects(id, name, created_at)` = job folders. `walls(id, project_id, title, data jsonb, photo_path, thumb, created_at, updated_at)`. The editable annotation state (same shape as `projectData()`, **minus** the photo) goes in `data`; the photo bytes go to the `survey-photos` Storage bucket at `<project_id>/<wall_id>.<ext>`; a small JPEG preview goes in `thumb` for the browse grid.
- **Round-trip**: save = insert wall row → upload photo → patch row with `photo_path`+`thumb`. Open = fetch row → download photo from Storage as a **data URL** (kept self-contained so PNG/PDF/SVG export stays offline-safe and canvas never taints) → `restoreProject()`. Reuses the exact same restore path as reopening a local file, so the editable round-trip is identical.
- **Access**: launches open-access (no login) per roadmap — RLS policies allow the anon role full read/write. Auth gate (roadmap #2) tightens this later.
- **Setup SQL** to run once in the Supabase SQL editor lives with the session notes; it is idempotent (safe to re-run) and creates both tables, the bucket, and the open-access policies.

## Project-first workflow (added July 9, 2026)

The app now **opens on a Projects home screen** (`#home`, full-screen overlay). Flow:
- **Projects list** — your job folders + **➕ New Project** and **✏️ Quick edit (no project)** (the local-first escape hatch).
- **Open a project** — thumbnail grid of that job's photos (walls) + **➕ Add photos** (multi-select) and **📷 Take photo**; both drop straight into the open project. `S.projectId`/`S.projectName` track the open project.
- **Tap a photo** → `editWall()` downloads it and opens the existing editor, binding `S.wallId`. A teal **📁 project** badge (`#ctx`) shows in the toolbar.
- **Saving is explicit.** The drawer button is renamed **✓ Apply** (applies one label; not "done editing"). The **Save** menu is context-aware: editing a project photo shows **💾 Save to <project>** (`saveWallUpdate()` — PATCHes `data`+`thumb` in place); a local one-off shows **☁ Save to a project** (creates a new wall, then binds to it). Local PDF/PNG/SVG export is always present.
- **🗂 Projects** toolbar button returns home (`goHome()` warns if `S.dirty` and unsaved). Photos added without annotating store `lines:[]` and a plain downscaled thumb.
- Helpers: `createWall()` (insert→upload→patch), `processFilesIntoProject()`, `decodeFile()` (HEIC-aware), `makeThumbFromImg()`.

## iOS/iPad viewport fixes (July 9, 2026)

The keyboard "toolbar disappears / app frozen" bug: iOS scrolls/shifts the fixed layout to reveal a focused field and doesn't restore it. Fix: lock `html,body{overflow:hidden}`, `pinToTop()` on focusout/scroll, and clamp `html/body` height to `visualViewport.height` **only while a field is focused** (clamping always left photos shrunk by the picker's transient small viewport). Input font is 16px to stop iOS zoom.

## Working agreement for Claude Code sessions

- Read this file first. Keep it updated when features land (bump the date).
- One feature per session/commit where practical; small, revertible commits.
- Ryan reviews by testing the live site after Netlify deploys — tell him exactly what to test and on which device.
- Never commit secrets. The Supabase anon key is designed to be public (it will live in the HTML), but service keys must never appear in this repo.
