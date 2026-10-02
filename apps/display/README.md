# WantWise Display

Read-only household display for a 1080p monitor or TV. Design and architecture: [docs/DISPLAY.md](../../docs/DISPLAY.md).

```bash
npm install
npm run dev          # http://localhost:3000/display
npm test             # Vitest (includes docs/fixtures/countdown-cases.json shared with Swift)
npm run typecheck
npm run build && npm start   # production mode for an always-on screen
```

- **F** toggles full screen. **←/→** step through Wants. `?feature=N` starts on Want N.
- Data comes from `fixtures/wants.json` (`WANTWISE_DATA_SOURCE=fixture`, the default). Supabase arrives in Milestone 4.
- `npm run fixtures:images` regenerates the placeholder screenshots in `public/fixtures/`.
