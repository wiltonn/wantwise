# Capture

Capture is the core product requirement. A child sees something while *already inside another app*. WantWise must catch that impulse in a few seconds, without retyping anything.

## Capture methods

| Method | Entry point | sourceType | Milestone |
|---|---|---|---|
| Manual | "Add Want" in app | `manual` | 1 |
| Screenshot | Screenshot → Share → WantWise | `screenshot` | 2 |
| Shared URL | Safari/any app → Share → WantWise | `sharedURL` | 2 |
| Shared text | Any app → Share → WantWise | `sharedText` | 2 |
| Photo | "Add Want" → camera / photo library | `photo` | 2 |

No OCR, vision, or AI in V1. The screenshot itself *is* the record — the child recognises it later by sight.

## The screenshot workflow (target experience)

```
[Child in Amazon / a game / YouTube]
   │  side + volume-up
   ▼
[Screenshot thumbnail] ── tap ──▶ [Markup editor] ── Share ──▶ [Share sheet]
                                                                  │ tap "WantWise"
                                                                  ▼
┌──────────────────────────────────────────┐
│  Want this?                         ✕    │
│  ┌────────────────────────────────────┐  │
│  │                                    │  │
│  │      [large screenshot preview]    │  │
│  │                                    │  │
│  └────────────────────────────────────┘  │
│  What is it? (optional)  [____________]  │
│  What makes you want it? [____________]  │
│                                          │
│  Think about it for:                     │
│  ( 3 days ) ( 7 days ) ( 30 days ) (…)   │
│                                          │
│  [        Add to WantWise         ]      │
└──────────────────────────────────────────┘
          │
          ▼
  "Saved. Let's think about this again on Fri, Oct 9."  (auto-dismiss ~1.5s)
```

Target: **under 10 seconds** from share sheet to done. Only the image is required. Price and "do you have something similar?" are *not* asked in the extension — they can be added later in the app. If the child taps Add without a reason or wait choice, the Want is saved as `captured` and the app shows it as "Finish thinking about this".

The child should pin WantWise to the front of the share sheet's app row once (Share → More → Edit → favourite). We'll note this in onboarding.

## What runs in the Share Extension vs. the main app

### Apple's constraints (verify on Mac where marked)

| Constraint | Consequence |
|---|---|
| A Share Extension is a **separate process** with its own lifecycle, launched by the host app, and can be terminated once it completes or if it misbehaves. | All capture work must finish before `completeRequest`. Writes must be atomic. |
| Share Extensions have a **much lower memory limit** than apps (commonly ~120 MB; not formally documented). Decoding a full-resolution image naively (e.g. a Safari full-page screenshot) can get the extension killed. | Downsample with ImageIO (`CGImageSourceCreateThumbnailAtIndex`) directly from the file/data — never load the full `UIImage`. |
| **No supported way to open the containing app** from a Share Extension. `NSExtensionContext.open(_:)` is only supported for Today/widget-style extensions; responder-chain `openURL` tricks are unsupported and fragile. | The extension must complete the whole capture itself. It cannot "hand off to the app to finish". |
| The extension and the app only share data via an **App Group** container (shared files, shared `UserDefaults`, or a shared database file). | Both targets get the same App Group entitlement (build setting `WANTWISE_APP_GROUP`, placeholder `group.tech.wantwise.app`). Used **only** for the inbox (D-019). |
| The extension declares what it accepts in `NSExtensionActivationRule` in its Info.plist. | Accept: 1 image, 1 web URL, text. |
| Safari's screenshot UI can produce a **"Full Page" PDF** instead of an image. | V1: accept images and URLs; treat PDF as a stretch (render page 1 to an image). [MAC REQUIRED to verify behaviour] |
| Item providers are async (`NSItemProvider.loadFileRepresentation` / `loadItem`). Shared items may arrive as file URLs, `Data`, or `UIImage`, depending on the host app. | Handle `public.image` via file representation first, fall back to data. |
| Network fetching (link previews) from an extension is allowed but slow and may be cut short. | Don't fetch URL metadata in the extension. The app fetches `LPMetadataProvider` previews later, on import. |
| Local notifications: scheduling via `UNUserNotificationCenter` from an extension is expected to work if the app already has permission. [MAC REQUIRED to verify] | The V1 extension does **not** schedule (D-030). The app **reconciles** all reminders when it next comes to the foreground and imports the inbox. Revisit if children capture without opening the app for days. |
| Extension UI is a `UIViewController`; SwiftUI is hosted via `UIHostingController`. | Shared SwiftUI components (image preview, wait-duration picker) live in a small shared source group used by both targets. |

### Decision: the extension writes to an App Group **inbox**, the app imports

```
Share Extension                              Main app
───────────────                              ────────
1. Load item (image / URL / text)
2. Downsample image → JPEG (max 2048 px)
3. Show "Want this?" UI
4. On Add:
   a. write  Inbox/<uuid>.jpg
   b. write  Inbox/<uuid>.json   ◀── written LAST, atomically;
      (CapturedWant: id, title, reason,        its presence means "complete"
       sourceType, url, text, waitDays,
       revisitAt, createdAt)
   c. schedule local notification (best effort)
   d. completeRequest
                                             On launch / scenePhase .active:
                                             5. scan Inbox/*.json
                                             6. move image → app container Images/<uuid>.jpg
                                             7. insert Want (status captured or waiting),
                                                skip if id already exists (idempotent)
                                             8. delete inbox files
                                             9. reconcile notifications
```

Why not have the extension write directly into the shared SwiftData store? It works, but means two processes writing one SQLite store, a `ModelContainer` loaded inside a memory-constrained extension, and schema-migration risk in two targets. The inbox is a few dozen lines of Codable + FileManager, needs no SwiftData in the extension, and is idempotent by UUID. Trade-off: a captured Want appears in the app when the app is next opened (instantly, on foreground). See DECISIONS.md D-008.

The `CapturedWant` Codable type lives in `WantWiseCore` so both targets (and Linux tests) share it.

## Shared URL

- Accept `public.url`. Store as `productURL`, `sourceType = sharedURL`.
- Title defaults to the URL host ("amazon.ca") until the app fetches link metadata on import (`LPMetadataProvider`: title + image). The fetched preview image becomes the Want's image if none was shared.
- Later option: Safari `NSExtensionJavaScriptPreprocessingFile` to read the page title / `og:image` directly from the page in the extension.

## Shared text

Store as `details`, first line (truncated) as title. If the text contains a URL, extract it to `productURL` (`NSDataDetector`, no AI).

## Photo (in app)

`PhotosPicker` for library, a thin camera wrapper for "Take photo". Same downsample + Images/ storage as screenshots.

## Image storage

- `Application Support/Images/<want-uuid>.jpg` in the **app's own container** (D-019). The extension writes its downsampled image into the App Group `Inbox/`; the app moves it into `Images/` on import. Only the inbox depends on the team-registered App Group ID.
- Max 2048 px long edge, JPEG ~0.8 quality. A tall screenshot stays readable; typical size 200–600 KB.
- A small thumbnail can be derived on demand; not stored separately in V1.
- Milestone 3: uploaded to Supabase Storage at `family/<familyId>/wants/<wantId>.jpg`. See ARCHITECTURE.md → Image sync.

## Testing capture

| What | Where |
|---|---|
| `CapturedWant` encode/decode, inbox import idempotency, text→URL extraction, title fallback | `WantWiseCore` unit tests (WSL with Swift toolchain, or Mac) |
| Image downsampling | App unit test [MAC REQUIRED] |
| Share Extension end-to-end (Photos, Safari, screenshot markup, Amazon app) | Manual checklist on device via TestFlight [MAC REQUIRED to build] |
