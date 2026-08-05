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

## Features

| Tab | Feature |
|-----|---------|
| **Log** | Import ADIF `.adi` files, searchable list, POTA/SOTA filter, swipe-to-delete, export full log |
| **Detail** | Tap any QSO to add a photo, POTA reference, or SOTA reference |
| **Stats** | Totals, LoTW confirmations, DXCC entities, US states, band/mode/year breakdowns |
| **Awards** | Progress toward DXCC Challenge, Worked All States, POTA Hunter, IOTA, CQ Zones |
| **Map** | Plot QSOs by grid square on MapKit |
| **Tools** | QRZ.com callsign lookup (uses QRZ username/password), Maidenhead grid-square decoder, distance/bearing calculator |
| **Space** | Live solar flux, A/K index, sunspot number from NOAA/SILSO |
| **Sats** | Amateur satellite list, frequency/mode info, CelesTrak TLE fetch, approximate pass predictions |
| **Settings** | Callsign, name, grid, location, **QRZ Logbook API key**, **QRZ username/password** for callsign lookup, accent color, dark/light/system theme |

## Project layout

- `VibeHamToolkit/` — iOS app source and Xcode project
  - `VibeHamToolkit/Models.swift` — SwiftData models
  - `VibeHamToolkit/ADIFParser.swift` / `ADIFExporter.swift` — ADIF import/export
  - `VibeHamToolkit/QRZService.swift` — QRZ.com XML lookup
  - `VibeHamToolkit/SatelliteService.swift` — TLE fetch + simplified pass predictor
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

### Sample ADIF for testing

A sample ADIF file is included in this repo at `sample-test.adi`. Use it to test the import flow:

1. Open the app
2. Go to the **Log** tab
3. Tap the import (⬇️) button
4. Select `sample-test.adi`

## Notes

- **QRZ lookup** requires a QRZ.com XML Logbook Data API key entered in **Settings**.
- **Satellite pass predictions** use a simplified Keplerian propagator and are approximate; for exact tracking, an SGP4 implementation can be swapped in later.
- All data lives in the app's SwiftData store on your device. No server, no Pi, no website required.
