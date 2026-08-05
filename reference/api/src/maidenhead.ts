export type LatLon = { lat: number; lon: number };

/** Converts a Maidenhead grid locator (4, 6, or 8 chars) to its center point. */
export function gridToLatLon(grid: string): LatLon | null {
  const g = grid.trim().toUpperCase();
  if (g.length < 4 || g.length % 2 !== 0) return null;
  if (!/^[A-R]{2}[0-9]{2}([A-X]{2}([0-9]{2})?)?$/.test(g)) return null;

  let lon = (g.charCodeAt(0) - 65) * 20 - 180;
  let lat = (g.charCodeAt(1) - 65) * 10 - 90;
  lon += Number(g[2]) * 2;
  lat += Number(g[3]) * 1;
  let lonCell = 2;
  let latCell = 1;

  if (g.length >= 6) {
    lon += (g.charCodeAt(4) - 65) * (2 / 24);
    lat += (g.charCodeAt(5) - 65) * (1 / 24);
    lonCell = 2 / 24;
    latCell = 1 / 24;
  }
  if (g.length >= 8) {
    lon += Number(g[6]) * (lonCell / 10);
    lat += Number(g[7]) * (latCell / 10);
    lonCell /= 10;
    latCell /= 10;
  }

  // Center of the smallest resolved cell.
  return { lat: lat + latCell / 2, lon: lon + lonCell / 2 };
}

/** Parses an ADIF LAT/LON value, e.g. "N044 20.239" (degrees + decimal minutes). */
export function parseAdifLatLon(value: string): number | null {
  const m = value.trim().match(/^([NSEW])(\d+)\s+(\d+(?:\.\d+)?)$/i);
  if (!m) return null;
  const [, hemi, degStr, minStr] = m;
  const deg = Number(degStr) + Number(minStr) / 60;
  return hemi.toUpperCase() === 'S' || hemi.toUpperCase() === 'W' ? -deg : deg;
}

/** Resolves the best available coordinate for a station: explicit LAT/LON first, grid square as fallback. */
export function resolveLatLon(lat?: string, lon?: string, grid?: string): LatLon | null {
  if (lat && lon) {
    const parsedLat = parseAdifLatLon(lat);
    const parsedLon = parseAdifLatLon(lon);
    if (parsedLat !== null && parsedLon !== null) return { lat: parsedLat, lon: parsedLon };
  }
  return grid ? gridToLatLon(grid) : null;
}
