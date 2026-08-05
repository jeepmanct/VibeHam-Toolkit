# VibeHam Toolkit

An iOS amateur-radio toolkit that keeps your data on your phone. It replaces the personal website model with a native SwiftUI app using local SwiftData storage.

> **Original repo left untouched:** The source repo `jeepmanct/N1AH` remains as-is and in development. This repo is a scrubbed, public, mobile-first re-implementation.

## What was scrubbed

All personally identifying information from the reference implementation was removed or templated before publishing:

- Callsigns replaced with `{CALLSIGN}` placeholders
- GitHub username replaced with `{GITHUB_USER}`
- Host/machine references replaced with `{HOST}`
- Data-directory paths replaced with `{DATA_DIR}`
- Deployment-specific systemd units, Caddyfile, and `.env` files removed
- Password/QRZ-key setup scripts removed
- No log data, ADIF files, or photos are committed

## Features (v1)

- **Local QSO Log** — import ADIF (`.adi`) files from LoTW or other logbooks; stored in SwiftData
- **Stats** — totals, LoTW confirmations, DXCC entity count, band/mode/year breakdowns
- **Map** — plot QSOs by grid square on a MapKit map
- **Tools** — Maidenhead grid-square decoder, distance/bearing calculator
- **Space Weather** — live solar flux, A/K index, and sunspot number from NOAA/SILSO
- **Settings** — configure your callsign, grid, location, QRZ API key, accent color, and dark/light/system theme

## Project layout

- `VibeHamToolkit/` — iOS app source and Xcode project
  - `VibeHamToolkit/Models.swift` — SwiftData models
  - `VibeHamToolkit/ADIFParser.swift` — ADIF file parser
  - `VibeHamToolkit/*View.swift` — SwiftUI views
  - `project.yml` — xcodegen project spec
- `reference/` — scrubbed copy of the original web/API codebase for reference only

## Build & run

```sh
cd VibeHamToolkit
xcodegen generate
xcodebuild -project VibeHamToolkit.xcodeproj \
           -scheme VibeHamToolkit \
           -destination 'platform=iOS Simulator,name=iPhone 17' \
           build CODE_SIGNING_ALLOWED=NO
```

To run on a physical iPhone, open `VibeHamToolkit.xcodeproj` in Xcode, set your team/signing, and build to device.

## Roadmap

- QRZ.com callsign lookup (uses the API key in Settings)
- Satellite pass predictions with fetched TLEs
- Photo log entries
- Awards progress (DXCC, WAS, POTA)
- Export ADIF
