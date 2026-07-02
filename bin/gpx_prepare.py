#!/usr/bin/env python3
"""
gpx_prepare.py — merge GPX files and extract geotagged photo positions.

Usage:
  python3 gpx_prepare.py merge <out.gpx> <in1.gpx> [in2.gpx ...]
  python3 gpx_prepare.py photos <gallery_dir> <out_photos.json>

The 'merge' command concatenates multiple GPX tracks into one file,
sorting all trackpoints by time so overnight/multi-file trips stitch
correctly. If timestamps are missing it falls back to file order.

The 'photos' command scans a directory for JPEGs with embedded GPS EXIF
and writes a JSON array used by the map shortcode:
  [{ "file": "img.jpg", "lat": -41.5, "lon": 173.2, "alt": 842, "time": "..." }, ...]

Requires: exiftool on PATH (already used in your Immich workflow).
"""

import json
import os
import subprocess
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

GPX_NS  = "http://www.topografix.com/GPX/1/1"
GPX_HDR = '<?xml version="1.0" encoding="UTF-8"?>\n'

ET.register_namespace("", GPX_NS)


# ── helpers ──────────────────────────────────────────────────────────────────

def parse_time(s):
    """Parse ISO-8601 / GPX timestamp → datetime (UTC). Returns None on failure."""
    if not s:
        return None
    for fmt in ("%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%dT%H:%M:%S.%fZ",
                "%Y-%m-%dT%H:%M:%S%z"):
        try:
            dt = datetime.strptime(s.strip(), fmt)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt
        except ValueError:
            pass
    return None


def trkpt_time(trkpt):
    """Return datetime for a <trkpt> element, or None."""
    t = trkpt.find(f"{{{GPX_NS}}}time")
    return parse_time(t.text) if t is not None else None


# ── merge ─────────────────────────────────────────────────────────────────────

def merge(output_path, input_paths):
    all_trkpts = []

    for path in input_paths:
        tree = ET.parse(path)
        root = tree.getroot()
        pts  = root.findall(f".//{{{GPX_NS}}}trkpt")
        valid = [p for p in pts if trkpt_time(p) is not None]
        skipped = len(pts) - len(valid)
        if skipped:
            print(f"  WARNING: {skipped} point(s) with no timestamp dropped from {os.path.basename(path)}")
        if not valid:
            print(f"  WARNING: {os.path.basename(path)} has NO timestamped points — skipping entirely (route file?)")
            continue
        print(f"  {os.path.basename(path)}: {len(valid)} trackpoints (of {len(pts)})")
        all_trkpts.extend(valid)

    # Sort by time if timestamps present, otherwise preserve order
    has_times = any(trkpt_time(p) for p in all_trkpts)
    if has_times:
        all_trkpts.sort(key=lambda p: trkpt_time(p) or datetime.min.replace(tzinfo=timezone.utc))
        print(f"  Sorted {len(all_trkpts)} points by timestamp.")
    else:
        print(f"  No timestamps found — preserving file order.")

    # Build output GPX
    gpx = ET.Element(f"{{{GPX_NS}}}gpx", {
        "version": "1.1",
        "creator": "gpx_prepare.py",
        "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        "xsi:schemaLocation": (
            "http://www.topografix.com/GPX/1/1 "
            "http://www.topografix.com/GPX/1/1/gpx.xsd"
        ),
    })
    trk  = ET.SubElement(gpx, f"{{{GPX_NS}}}trk")
    trkseg = ET.SubElement(trk, f"{{{GPX_NS}}}trkseg")
    for pt in all_trkpts:
        trkseg.append(pt)

    tree_out = ET.ElementTree(gpx)
    ET.indent(tree_out, space="  ")
    with open(output_path, "wb") as f:
        f.write(GPX_HDR.encode())
        tree_out.write(f, encoding="utf-8", xml_declaration=False)

    print(f"  → Wrote {len(all_trkpts)} points to {output_path}")


# ── photos ────────────────────────────────────────────────────────────────────

def extract_photos(gallery_dir, output_json):
    exts = {".jpg", ".jpeg"}
    images = sorted(
        f for f in os.listdir(gallery_dir)
        if os.path.splitext(f)[1].lower() in exts
    )

    if not images:
        print("  No JPEG images found.")
        with open(output_json, "w") as f:
            json.dump([], f)
        return

    # Use exiftool to batch-extract GPS + datetime
    cmd = [
        "exiftool",
        "-json",
        "-GPSLatitude#",   "-GPSLongitude#",  "-GPSAltitude#",
        "-SubSecDateTimeOriginal", "-DateTimeOriginal",
        "-FileName",
    ] + [os.path.join(gallery_dir, img) for img in images]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    except FileNotFoundError:
        print("ERROR: exiftool not found on PATH. Install it and retry.")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"ERROR: exiftool failed:\n{e.stderr}")
        sys.exit(1)

    records = json.loads(result.stdout)
    photos = []
    skipped = 0

    for r in records:
        lat = r.get("GPSLatitude")
        lon = r.get("GPSLongitude")
        if lat is None or lon is None:
            skipped += 1
            continue

        time_str = r.get("SubSecDateTimeOriginal") or r.get("DateTimeOriginal") or ""
        photos.append({
            "file": r["FileName"],
            "lat":  round(float(lat), 7),
            "lon":  round(float(lon), 7),
            "alt":  round(float(r["GPSAltitude"]), 1) if r.get("GPSAltitude") else None,
            "time": time_str,
        })

    with open(output_json, "w") as f:
        json.dump(photos, f, indent=2)

    print(f"  → {len(photos)} geotagged photos written to {output_json}")
    if skipped:
        print(f"  → {skipped} photos skipped (no GPS data)")


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "merge":
        if len(sys.argv) < 4:
            print("Usage: gpx_prepare.py merge <out.gpx> <in1.gpx> [in2.gpx ...]")
            sys.exit(1)
        merge(sys.argv[2], sys.argv[3:])

    elif cmd == "photos":
        if len(sys.argv) != 4:
            print("Usage: gpx_prepare.py photos <gallery_dir> <out_photos.json>")
            sys.exit(1)
        extract_photos(sys.argv[2], sys.argv[3])

    else:
        print(f"Unknown command: {cmd}")
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
