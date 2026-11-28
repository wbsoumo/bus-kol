#!/usr/bin/env python3
"""
Builds compact offline transit assets for CholoKolkata:
  - cholo_kolkata/assets/kolkata_auto_routes.json
  - cholo_kolkata/assets/kolkata_ferry_routes.json
  - cholo_kolkata/assets/kolkata_rail_routes.json
  - cholo_kolkata/assets/kolkata_stop_coords.json
"""
import csv
import json
import math
import os
import re
from collections import defaultdict

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE_ROOT = "/Users/wbsoumo/.gemini/antigravity/brain/3e027ab4-b631-4ca3-bb4e-c4be8bbed4cd/scratch/calcutta-transport"
ASSETS_DIR = os.path.join(PROJECT_ROOT, "cholo_kolkata", "assets")


def read_csv(rel_path):
    full = os.path.join(SOURCE_ROOT, rel_path)
    with open(full, "r", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def norm_name(s):
    s = re.sub(r"\([^)]*\)", " ", (s or "").lower())
    s = re.sub(r"[^a-z0-9 ]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def haversine_km(lat1, lon1, lat2, lon2):
    p = math.pi / 180.0
    a = (
        0.5
        - math.cos((lat2 - lat1) * p) / 2.0
        + math.cos(lat1 * p) * math.cos(lat2 * p) * (1.0 - math.cos((lon2 - lon1) * p)) / 2.0
    )
    return 12742.0 * math.asin(min(1.0, math.sqrt(max(0.0, a))))


def in_kolkata_box(lat, lon):
    return 22.15 <= lat <= 23.05 and 87.95 <= lon <= 88.75


def build_coord_index():
    coord_map = {}

    def put(name, lat, lon, force=False):
        k = norm_name(name)
        if not k:
            return
        if force or k not in coord_map:
            coord_map[k] = (round(lat, 6), round(lon, 6))

    # 1. Existing app KolkataGeo landmarks (curated & authoritative)
    geo_path = os.path.join(PROJECT_ROOT, "cholo_kolkata", "lib", "services", "kolkata_geo.dart")
    with open(geo_path, "r", encoding="utf-8") as f:
        geo_txt = f.read()
    for name, lat, lon in re.findall(
        r"'([^']+)':\s*const\s+LatLng\(([^,]+),\s*([^)]+)\)", geo_txt
    ):
        put(name, float(lat), float(lon), force=True)
    put("bandhaghat", 22.600591, 88.350798, force=True)

    # 2. Transit CSV stops (Metro, Rail, Ferry, Bus, Auto)
    for rel in (
        "data/metro/stops.csv",
        "data/rail/stops.csv",
        "data/ferry/stops.csv",
        "data/bus/stops.csv",
        "data/auto/stops.csv",
    ):
        for r in read_csv(rel):
            lat_s = (r.get("lat") or "").strip()
            lon_s = (r.get("lon") or "").strip()
            if lat_s and lon_s:
                put(r["stop_name"], float(lat_s), float(lon_s))

    # 3. places.json (prefer transit/area/crossing/landmark entries inside Greater Kolkata)
    places_path = os.path.join(SOURCE_ROOT, "docs", "data", "places.json")
    with open(places_path, "r", encoding="utf-8") as f:
        places_data = json.load(f)
    p_list = places_data.get("p", [])
    # Sort higher rank first, prefer Kolkata bounding box
    scored_places = []
    for row in p_list:
        pname = str(row[0])
        lat, lon = float(row[1]), float(row[2])
        rank = int(row[4]) if len(row) > 4 else 0
        box_bonus = 100 if in_kolkata_box(lat, lon) else 0
        scored_places.append((box_bonus + rank, pname, lat, lon, row[6] if len(row) > 6 else ""))
    scored_places.sort(key=lambda x: -x[0])

    for _, pname, lat, lon, alts in scored_places:
        put(pname, lat, lon)
        if alts:
            for alt in str(alts).split("|"):
                put(alt, lat, lon)

    return coord_map


def lookup_coord(name, coord_map):
    k = norm_name(name)
    if k in coord_map:
        return coord_map[k]
    k2 = re.sub(
        r"\b(more|mord|stand|auto stand|bus stand|bus stop|crossing|junction|stn|station|bazar|bazaar|market|cinema|gate|mor|ghat)\b",
        "",
        k,
    ).strip()
    k2 = re.sub(r"\s+", " ", k2)
    if k2 and k2 in coord_map:
        return coord_map[k2]
    return None


def interpolate_stop_coords(stops_objs):
    """Linearly fills missing lat/lon between known anchors along a route."""
    known = [i for i, s in enumerate(stops_objs) if s.get("lat") is not None and s.get("lon") is not None]
    if not known:
        return
    # Fill leading gaps by shifting slightly only if <= 2 stops? Better leave unknown if outer anchor missing,
    # OR copy nearest terminal only? Let's interpolate strictly BETWEEN known anchors so we never distort terminals.
    for idx_pos in range(len(known) - 1):
        a = known[idx_pos]
        b = known[idx_pos + 1]
        if b - a <= 1:
            continue
        lat1, lon1 = stops_objs[a]["lat"], stops_objs[a]["lon"]
        lat2, lon2 = stops_objs[b]["lat"], stops_objs[b]["lon"]
        if haversine_km(lat1, lon1, lat2, lon2) > 18.0:
            continue
        span = b - a
        for mid in range(a + 1, b):
            frac = (mid - a) / span
            stops_objs[mid]["lat"] = round(lat1 + (lat2 - lat1) * frac, 6)
            stops_objs[mid]["lon"] = round(lon1 + (lon2 - lon1) * frac, 6)
            stops_objs[mid]["ex"] = 0


def parse_route_km(stops_objs, notes=""):
    m = re.search(r"(\d+(?:\.\d+)?)\s*km", notes or "", re.I)
    if m:
        return round(float(m.group(1)), 1)
    total = 0.0
    prev = None
    for s in stops_objs:
        if s.get("lat") is not None and s.get("lon") is not None:
            cur = (s["lat"], s["lon"])
            if prev is not None:
                total += haversine_km(prev[0], prev[1], cur[0], cur[1])
            prev = cur
    if total > 0.2:
        return round(total * 1.18, 1)  # road factor ~1.18x
    return round(max(1.8, (len(stops_objs) - 1) * 0.9), 1)


def auto_fare_slab(km):
    if km <= 2.5:
        return (10, 12)
    if km <= 5.0:
        return (12, 15)
    if km <= 8.5:
        return (15, 20)
    return (20, 25)


def extract_auto_code(route_id, notes, origin, dest):
    m = re.search(r"Route no\s*([A-Za-z0-9\-\/]+)", notes or "", re.I)
    if m:
        return f"A-{m.group(1).upper()}"
    m2 = re.match(r"auto_r([a-z0-9]+)$", route_id or "", re.I)
    if m2:
        return f"A-{m2.group(1).upper()}"
    m3 = re.search(r"serial\s*(\d+)", notes or "", re.I)
    if m3:
        return f"RTA-{m3.group(1)}"
    return "AUTO"


def build_auto(coord_map):
    routes = read_csv("data/auto/routes.csv")
    stops = {s["stop_id"]: s for s in read_csv("data/auto/stops.csv")}
    rs_rows = read_csv("data/auto/route_stops.csv")

    by_route_dir = defaultdict(list)
    for r in rs_rows:
        by_route_dir[(r["route_id"], r.get("direction", "0"))].append(r)

    out = []
    exact_count = 0
    interp_count = 0

    for idx, r in enumerate(routes, start=1):
        rid = r["route_id"]
        # Prefer dir 0
        seq_rows = by_route_dir.get((rid, "0")) or by_route_dir.get((rid, "1")) or []
        seq_rows.sort(key=lambda x: int(x.get("seq") or 0))
        if not seq_rows:
            continue

        stops_objs = []
        for srow in seq_rows:
            sid = srow["stop_id"]
            st = stops.get(sid, {"stop_name": sid})
            sname = st["stop_name"].strip()
            lat_s = (st.get("lat") or "").strip()
            lon_s = (st.get("lon") or "").strip()
            lat = lon = None
            is_exact = 0
            if lat_s and lon_s:
                lat, lon = round(float(lat_s), 6), round(float(lon_s), 6)
                is_exact = 1
            else:
                found = lookup_coord(sname, coord_map)
                if found:
                    lat, lon = found
                    is_exact = 1
            obj = {"n": sname}
            if lat is not None and lon is not None:
                obj["lat"] = lat
                obj["lon"] = lon
                obj["ex"] = is_exact
                exact_count += 1
            stops_objs.append(obj)

        interpolate_stop_coords(stops_objs)
        interp_count += sum(1 for s in stops_objs if s.get("lat") is not None and s.get("ex") == 0)

        km = parse_route_km(stops_objs, r.get("notes", ""))
        total_min = max(6, round((km / 18.0) * 60))
        n_stops = max(1, len(stops_objs) - 1)
        for si, so in enumerate(stops_objs):
            so["m"] = round((si / n_stops) * total_min)

        fmin = int(float(r["fare_min_inr"])) if r.get("fare_min_inr") else auto_fare_slab(km)[0]
        fmax = int(float(r["fare_max_inr"])) if r.get("fare_max_inr") else auto_fare_slab(km)[1]
        if fmax < fmin:
            fmax = fmin

        hw_peak = int(r["headway_min_peak"]) if r.get("headway_min_peak") else 6
        hw_off = int(r["headway_min_offpeak"]) if r.get("headway_min_offpeak") else 10
        fs = r.get("first_service") or "06:00"
        ls = r.get("last_service") or "22:30"

        code = extract_auto_code(rid, r.get("notes", ""), r["origin"], r["destination"])
        notes_clean = re.sub(r"\s+", " ", (r.get("notes") or "")).strip()
        if len(notes_clean) > 160:
            notes_clean = notes_clean[:157] + "..."

        out.append(
            {
                "id": 70000 + idx,
                "rid": rid,
                "r": code,
                "rn": r["route_name"],
                "f": r["origin"] or stops_objs[0]["n"],
                "t": r["destination"] or stops_objs[-1]["n"],
                "hwP": hw_peak,
                "hwO": hw_off,
                "fs": fs,
                "ls": ls,
                "fMin": fmin,
                "fMax": fmax,
                "km": km,
                "dur": total_min,
                "nt": notes_clean,
                "stops": stops_objs,
            }
        )

    print(f"Auto: {len(out)} routes, stop-points exact={exact_count}, interp={interp_count}")
    return out


def build_ferry(coord_map):
    routes = read_csv("data/ferry/routes.csv")
    stops = {s["stop_id"]: s for s in read_csv("data/ferry/stops.csv")}
    rs_rows = read_csv("data/ferry/route_stops.csv")

    by_route_dir = defaultdict(list)
    for r in rs_rows:
        by_route_dir[(r["route_id"], r.get("direction", "0"))].append(r)

    out = []
    for idx, r in enumerate(routes, start=1):
        rid = r["route_id"]
        seq_rows = by_route_dir.get((rid, "0")) or []
        seq_rows.sort(key=lambda x: int(x.get("seq") or 0))
        if not seq_rows:
            continue

        stops_objs = []
        for srow in seq_rows:
            st = stops[srow["stop_id"]]
            t_min = int(float(srow["travel_min_from_start"])) if srow.get("travel_min_from_start") else 0
            lat_s = (st.get("lat") or "").strip()
            lon_s = (st.get("lon") or "").strip()
            obj = {
                "n": st["stop_name"].strip(),
                "m": max(0, t_min),
            }
            if lat_s and lon_s:
                obj["lat"] = round(float(lat_s), 6)
                obj["lon"] = round(float(lon_s), 6)
            else:
                found = lookup_coord(st["stop_name"], coord_map)
                if found:
                    obj["lat"], obj["lon"] = found
            stops_objs.append(obj)
        interpolate_stop_coords(stops_objs)

        km = parse_route_km(stops_objs)
        dur = stops_objs[-1]["m"] if stops_objs[-1]["m"] > 0 else max(6, round((km / 14.0) * 60))
        fmin = int(float(r["fare_min_inr"])) if r.get("fare_min_inr") else 8
        fmax = int(float(r["fare_max_inr"])) if r.get("fare_max_inr") else fmin
        hw_peak = int(r["headway_min_peak"]) if r.get("headway_min_peak") else 15
        hw_off = int(r["headway_min_offpeak"]) if r.get("headway_min_offpeak") else hw_peak

        out.append(
            {
                "id": 80000 + idx,
                "rid": rid,
                "r": f"FERRY-{idx}",
                "rn": r["route_name"],
                "op": r.get("operator") or "WBSTC / Hooghly Ferry",
                "f": r["origin"],
                "t": r["destination"],
                "hwP": hw_peak,
                "hwO": hw_off,
                "fs": r.get("first_service") or "07:00",
                "ls": r.get("last_service") or "20:00",
                "fMin": fmin,
                "fMax": fmax,
                "km": km,
                "dur": dur,
                "nt": re.sub(r"\s+", " ", (r.get("notes") or "")).strip()[:180],
                "stops": stops_objs,
            }
        )

    print(f"Ferry: {len(out)} routes, {sum(len(x['stops']) for x in out)} stop-entries")
    return out


def time_to_mins(tstr):
    parts = (tstr or "").strip().split(":")
    if len(parts) < 2:
        return None
    h, m = int(parts[0]), int(parts[1])
    return h * 60 + m


def mins_to_hhmm(m):
    m = m % 1440
    return f"{m // 60:02d}:{m % 60:02d}"


def build_rail():
    routes = read_csv("data/rail/routes.csv")
    stops = {s["stop_id"]: s for s in read_csv("data/rail/stops.csv")}
    rs_rows = read_csv("data/rail/route_stops.csv")
    tt_rows = read_csv("data/rail/timetable.csv")

    by_route_dir_stops = defaultdict(list)
    for r in rs_rows:
        by_route_dir_stops[(r["route_id"], r.get("direction", "0"))].append(r)

    # Group timetable trips by (route_id, direction, trip_id)
    trips = defaultdict(list)
    for row in tt_rows:
        trips[(row["route_id"], row.get("direction", "0"), row["trip_id"])].append(row)

    dir_departures = defaultdict(list)
    dir_trips_count = defaultdict(int)
    for (rid, d, tid), rows in trips.items():
        rows.sort(key=lambda x: int(x.get("seq") or 0))
        dep_m = time_to_mins(rows[0].get("departure") or rows[0].get("arrival"))
        if dep_m is not None:
            dir_departures[(rid, d)].append(dep_m)
            dir_trips_count[(rid, d)] += 1

    out = []
    for idx, r in enumerate(routes, start=1):
        rid = r["route_id"]
        dirs = []
        for d in ("0", "1"):
            seq_rows = by_route_dir_stops.get((rid, d))
            if not seq_rows:
                continue
            seq_rows.sort(key=lambda x: int(x.get("seq") or 0))

            stops_objs = []
            prev_m = 0
            for s_idx, srow in enumerate(seq_rows):
                st = stops[srow["stop_id"]]
                raw_m = (srow.get("travel_min_from_start") or "").strip()
                m_val = int(float(raw_m)) if raw_m and raw_m != "-1" else (0 if s_idx == 0 else prev_m + 3)
                if s_idx == 0:
                    m_val = 0
                elif m_val < prev_m:
                    m_val = prev_m + 2
                prev_m = m_val

                ir_code = ""
                m_code = re.search(r"IR code\s+([A-Z0-9]+)", st.get("notes", ""))
                if m_code:
                    ir_code = m_code.group(1)

                st_obj = {
                    "n": st["stop_name"].strip(),
                    "c": ir_code,
                    "m": m_val,
                }
                lat_s = (st.get("lat") or "").strip()
                lon_s = (st.get("lon") or "").strip()
                if lat_s and lon_s:
                    st_obj["lat"] = round(float(lat_s), 6)
                    st_obj["lon"] = round(float(lon_s), 6)
                stops_objs.append(st_obj)

            deps_sorted = sorted(set(dir_departures.get((rid, d), [])))
            deps_hhmm = [mins_to_hhmm(m) for m in deps_sorted]
            first_d = deps_hhmm[0] if deps_hhmm else (r.get("first_service") or "04:30")
            last_d = deps_hhmm[-1] if deps_hhmm else (r.get("last_service") or "23:15")

            dirs.append(
                {
                    "d": d,
                    "f": stops_objs[0]["n"],
                    "t": stops_objs[-1]["n"],
                    "cnt": dir_trips_count.get((rid, d), len(deps_hhmm)),
                    "fs": first_d,
                    "ls": last_d,
                    "dur": stops_objs[-1]["m"],
                    "km": parse_route_km(stops_objs),
                    "deps": deps_hhmm,
                    "stops": stops_objs,
                }
            )

        if not dirs:
            continue

        hw_peak = int(r["headway_min_peak"]) if r.get("headway_min_peak") else 20
        hw_off = int(r["headway_min_offpeak"]) if r.get("headway_min_offpeak") else 35
        short_code = rid.replace("rail_", "").upper().replace("_", "-")

        out.append(
            {
                "id": 90000 + idx,
                "rid": rid,
                "r": short_code,
                "rn": r["route_name"],
                "op": r.get("operator") or "Eastern / South Eastern Railway",
                "f": r["origin"],
                "t": r["destination"],
                "hwP": hw_peak,
                "hwO": hw_off,
                "fs": r.get("first_service") or dirs[0]["fs"],
                "ls": r.get("last_service") or dirs[0]["ls"],
                "fMin": int(float(r["fare_min_inr"])) if r.get("fare_min_inr") else 5,
                "fMax": int(float(r["fare_max_inr"])) if r.get("fare_max_inr") else 25,
                "dirs": dirs,
            }
        )

    print(f"Rail: {len(out)} corridors, {sum(len(d['stops']) for c in out for d in c['dirs'])} dir-stops, {sum(len(d['deps']) for c in out for d in c['dirs'])} departures")
    return out


def build_stop_coords(coord_map, auto_data, ferry_data, rail_data):
    """Exports compact normalized stop_name -> [lat, lon] lookup for all app bus stops + transit stops."""
    out_coords = {}

    def record(name, lat, lon):
        k = norm_name(name)
        if k and k not in out_coords:
            out_coords[k] = [round(lat, 5), round(lon, 5)]

    # Include all bus stops from kolkata_stops.json
    bus_stops_path = os.path.join(ASSETS_DIR, "kolkata_stops.json")
    with open(bus_stops_path, "r", encoding="utf-8") as f:
        bus_stops = json.load(f)
    matched_bus = 0
    for bs in bus_stops:
        sname = (bs.get("n") or "").strip()
        if not sname:
            continue
        found = lookup_coord(sname, coord_map)
        if found:
            record(sname, found[0], found[1])
            matched_bus += 1

    # Include curated KolkataGeo + Auto exact + Ferry + Rail + Metro coords
    for k, (lat, lon) in coord_map.items():
        # Include if metro/rail/ferry/auto stop or KolkataGeo landmark (keep file sleek)
        pass

    for r in auto_data:
        for s in r["stops"]:
            if "lat" in s and "lon" in s:
                record(s["n"], s["lat"], s["lon"])
    for r in ferry_data:
        for s in r["stops"]:
            if "lat" in s and "lon" in s:
                record(s["n"], s["lat"], s["lon"])
    for c in rail_data:
        for d in c["dirs"]:
            for s in d["stops"]:
                if "lat" in s and "lon" in s:
                    record(s["n"], s["lat"], s["lon"])
    for r in read_csv("data/metro/stops.csv"):
        if r.get("lat") and r.get("lon"):
            record(r["stop_name"], float(r["lat"]), float(r["lon"]))

    print(f"Stop Coords: {len(out_coords)} unique normalized transit stops (matched {matched_bus}/{len(bus_stops)} bus stops)")
    return out_coords


def main():
    coord_map = build_coord_index()
    auto_data = build_auto(coord_map)
    ferry_data = build_ferry(coord_map)
    rail_data = build_rail()
    stop_coords = build_stop_coords(coord_map, auto_data, ferry_data, rail_data)

    os.makedirs(ASSETS_DIR, exist_ok=True)
    files = {
        "kolkata_auto_routes.json": auto_data,
        "kolkata_ferry_routes.json": ferry_data,
        "kolkata_rail_routes.json": rail_data,
        "kolkata_stop_coords.json": stop_coords,
    }
    for fname, payload in files.items():
        fpath = os.path.join(ASSETS_DIR, fname)
        with open(fpath, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))
        sz = os.path.getsize(fpath)
        print(f"Wrote {fname}: {sz / 1024:.1f} KB")


if __name__ == "__main__":
    main()
