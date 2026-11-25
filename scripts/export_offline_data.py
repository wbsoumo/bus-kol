#!/usr/bin/env python3
"""
Exports all routes, route_stops, and stops from helnovexaa_buskolkata.sql
into compact offline JSON assets for the Flutter app.
"""
import json
import os
import re
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQL_PATH = os.path.join(ROOT, "helnovexaa_buskolkata.sql")
ASSETS_DIR = os.path.join(ROOT, "cholo_kolkata", "assets")


def parse_sql_tuples(insert_body: str):
    """Parse MySQL VALUES (...),(...) safely handling quoted strings and escapes."""
    rows = []
    i = 0
    n = len(insert_body)
    while i < n:
        if insert_body[i] != "(":
            i += 1
            continue
        i += 1
        fields = []
        while i < n:
            while i < n and insert_body[i] in " \t\r\n":
                i += 1
            if i >= n:
                break
            if insert_body[i] == "'":
                i += 1
                buf = []
                while i < n:
                    ch = insert_body[i]
                    if ch == "\\":
                        if i + 1 < n:
                            nxt = insert_body[i + 1]
                            if nxt == "n":
                                buf.append("\n")
                            elif nxt == "r":
                                buf.append("\r")
                            elif nxt == "t":
                                buf.append("\t")
                            else:
                                buf.append(nxt)
                            i += 2
                            continue
                    elif ch == "'":
                        if i + 1 < n and insert_body[i + 1] == "'":
                            buf.append("'")
                            i += 2
                            continue
                        i += 1
                        break
                    buf.append(ch)
                    i += 1
                fields.append("".join(buf))
            else:
                start = i
                while i < n and insert_body[i] not in ",)":
                    i += 1
                token = insert_body[start:i].strip()
                if token.upper() == "NULL":
                    fields.append(None)
                else:
                    try:
                        fields.append(int(token))
                    except ValueError:
                        try:
                            fields.append(float(token))
                        except ValueError:
                            fields.append(token)
            while i < n and insert_body[i] in " \t\r\n":
                i += 1
            if i < n and insert_body[i] == ",":
                i += 1
                continue
            if i < n and insert_body[i] == ")":
                i += 1
                break
        rows.append(fields)
    return rows


def extract_table_rows(sql_text: str, table_name: str):
    marker = f"INSERT INTO `{table_name}` VALUES"
    rows = []
    pos = 0
    while True:
        idx = sql_text.find(marker, pos)
        if idx == -1:
            break
        start = idx + len(marker)
        # Find terminating semicolon outside quotes
        i = start
        n = len(sql_text)
        in_quote = False
        while i < n:
            ch = sql_text[i]
            if in_quote:
                if ch == "\\":
                    i += 2
                    continue
                if ch == "'":
                    if i + 1 < n and sql_text[i + 1] == "'":
                        i += 2
                        continue
                    in_quote = False
            else:
                if ch == "'":
                    in_quote = True
                elif ch == ";":
                    break
            i += 1
        rows.extend(parse_sql_tuples(sql_text[start:i]))
        pos = i + 1
    return rows


def main():
    with open(SQL_PATH, "r", encoding="utf-8") as f:
        sql_text = f.read()

    raw_routes = extract_table_rows(sql_text, "routes")
    raw_route_stops = extract_table_rows(sql_text, "route_stops")
    raw_stops = extract_table_rows(sql_text, "stops")

    print(f"Parsed SQL -> routes: {len(raw_routes)}, route_stops: {len(raw_route_stops)}, stops: {len(raw_stops)}")
    assert len(raw_routes) >= 2172, f"Expected >=2172 routes, got {len(raw_routes)}"
    assert len(raw_route_stops) >= 42386, f"Expected >=42386 route_stops, got {len(raw_route_stops)}"
    assert len(raw_stops) >= 2327, f"Expected >=2327 stops, got {len(raw_stops)}"

    stops_by_route = defaultdict(list)
    for row in raw_route_stops:
        # (id, route_id, stop_order, stop_name, stop_clean)
        route_id, stop_order, stop_name = row[1], row[2], row[3]
        stops_by_route[route_id].append((stop_order, stop_name))

    routes_map = defaultdict(list)
    for row in raw_routes:
        # (id, route_no, route_name, origin, destination, category, bus_type, timetable, image_url, total_stops, created_at)
        rid = row[0]
        route_no = str(row[1]).strip()
        route_name = str(row[2]).strip()
        origin = str(row[3]).strip()
        destination = str(row[4]).strip()
        category = str(row[5]).strip()
        bus_type = str(row[6] or "City Bus").strip()
        timetable = str(row[7] or "").strip()
        image_url = str(row[8] or "").strip()

        ordered = sorted(stops_by_route.get(rid, []), key=lambda x: x[0])
        stop_names = [s[1] for s in ordered]
        if not stop_names:
            continue

        key = re.sub(r"\s+", "", route_no).upper()
        entry = {
            "id": rid,
            "r": route_no,
            "f": origin,
            "t": destination,
            "rn": route_name,
            "bt": bus_type,
            "cat": category,
            "s": stop_names,
        }
        if timetable and timetable != "Coming Soon":
            entry["tt"] = timetable
        if image_url:
            entry["img"] = image_url
        routes_map[key].append(entry)

    # Sort stops by routes_count DESC, length ASC
    stops_list = []
    seen_stops = set()
    for row in raw_stops:
        # (id, stop_name, routes_count)
        sname = str(row[1]).strip()
        cnt = int(row[2] or 0)
        if not sname or sname.lower() in seen_stops:
            continue
        seen_stops.add(sname.lower())
        stops_list.append({"n": sname, "c": cnt})
    stops_list.sort(key=lambda x: (-x["c"], len(x["n"]), x["n"].lower()))

    os.makedirs(ASSETS_DIR, exist_ok=True)
    routes_out = os.path.join(ASSETS_DIR, "kolkata_bus_routes.json")
    stops_out = os.path.join(ASSETS_DIR, "kolkata_stops.json")

    with open(routes_out, "w", encoding="utf-8") as f:
        json.dump(routes_map, f, ensure_ascii=False, separators=(",", ":"))
    with open(stops_out, "w", encoding="utf-8") as f:
        json.dump(stops_list, f, ensure_ascii=False, separators=(",", ":"))

    total_variants = sum(len(v) for v in routes_map.values())
    print(f"Exported {len(routes_map)} route keys ({total_variants} directional routes) -> {routes_out} ({os.path.getsize(routes_out):,} bytes)")
    print(f"Exported {len(stops_list)} unique stops -> {stops_out} ({os.path.getsize(stops_out):,} bytes)")


if __name__ == "__main__":
    main()
