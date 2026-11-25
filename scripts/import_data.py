import re
import pymysql
import os
import sys

def clean_stop(name):
    # remove trailing punctuation, brackets
    s = re.sub(r'\s*\([^)]*\)\s*', ' ', name)
    s = re.sub(r'[\.\:\,\_]+$', '', s).strip()
    return s

def parse_entry(raw, category):
    raw = raw.strip()
    if not raw:
        return None
    
    route_no = ''
    route_name = ''
    origin = ''
    destination = ''
    stops = []
    timetable = ''
    image_url = ''
    bus_type = 'Standard'

    via_match = re.search(r'\[\s*via\s*:\s*(.*?)\s*\]', raw, re.IGNORECASE)
    if via_match:
        before_via = raw[:via_match.start()].strip()
        after_via = raw[via_match.end():].strip()
        
        if ':' in before_via:
            parts = before_via.split(':', 1)
            route_no = parts[0].strip()
            route_name = parts[1].strip()
        else:
            route_no = before_via.strip()
            route_name = before_via.strip()
        
        raw_stops = via_match.group(1).split(',')
        for rs in raw_stops:
            cs = clean_stop(rs)
            if cs and cs not in stops:
                stops.append(cs)
        
        after_parts = [p.strip() for p in after_via.split(':') if p.strip()]
        if len(after_parts) >= 1:
            timetable = after_parts[0]
        if len(after_parts) >= 2:
            image_url = after_parts[1]
    elif ';timings-' in raw.lower():
        parts = re.split(r';timings-?', raw, flags=re.IGNORECASE)
        head = parts[0].strip()
        timetable = ('Timings: ' + parts[1].strip()) if len(parts) > 1 and parts[1].strip() else ''
        
        via_in_paren = re.search(r'\((?:Via|via)\s*([^)]+)\)', head)
        if via_in_paren:
            v_stops = via_in_paren.group(1).split(',')
            for rs in v_stops:
                cs = clean_stop(rs)
                if cs and cs not in stops:
                    stops.append(cs)
            head = head[:via_in_paren.start()] + head[via_in_paren.end():]
        elif ' via ' in head.lower():
            v_parts = re.split(r'\s+via\s+', head, flags=re.IGNORECASE)
            head = v_parts[0].strip()
            for rs in v_parts[1].split(','):
                cs = clean_stop(rs)
                if cs and cs not in stops:
                    stops.append(cs)

        route_name = head.strip()
        route_no = category
        if ' to ' in head.lower():
            to_parts = re.split(r'\s+to\s+', head, flags=re.IGNORECASE)
            origin = clean_stop(to_parts[0])
            destination = clean_stop(to_parts[1])
            route_no = f'{origin} - {destination}'
    else:
        parts = [p.strip() for p in raw.split(':') if p.strip()]
        if len(parts) >= 2:
            route_no = parts[0]
            route_name = parts[1]
        else:
            route_no = raw[:20]
            route_name = raw

    if not origin or not destination:
        if ' to ' in route_name.lower():
            to_parts = re.split(r'\s+to\s+', route_name, flags=re.IGNORECASE)
            origin = clean_stop(to_parts[0])
            destination = clean_stop(to_parts[1])
        elif stops:
            origin = stops[0]
            destination = stops[-1]
        else:
            origin = 'Unknown'
            destination = 'Unknown'
            
    if origin and (not stops or stops[0].lower() != origin.lower()):
        stops.insert(0, origin)
    if destination and (len(stops) < 2 or stops[-1].lower() != destination.lower()):
        stops.append(destination)
        
    combined_text = f'{route_no} {route_name} {raw}'.lower()
    if 'ac' in combined_text or 'air condition' in combined_text or route_no.upper().startswith('AC'):
        bus_type = 'AC Bus'
    elif 'mini' in combined_text:
        bus_type = 'Minibus'
    elif 'rocket' in combined_text:
        bus_type = 'Rocket / Express'
    elif 'express' in combined_text:
        bus_type = 'Express'
    elif 'cstc' in combined_text or 'wbtc' in combined_text or 'ctc' in combined_text:
        bus_type = 'WBTC State Bus'
    elif 'sbstc' in combined_text or category == 'SBSTC':
        bus_type = 'SBSTC State Bus'
    elif 'nbstc' in combined_text or category == 'NBSTC':
        bus_type = 'NBSTC State Bus'
    else:
        bus_type = 'City Bus (Private/State)'

    return {
        'route_no': route_no[:100],
        'route_name': route_name[:255],
        'origin': origin[:255],
        'destination': destination[:255],
        'category': category,
        'bus_type': bus_type,
        'timetable': timetable,
        'image_url': image_url[:255],
        'stops': stops
    }

def main():
    print("Connecting to MySQL...")
    try:
        conn = pymysql.connect(
            host='127.0.0.1',
            user='bususer',
            password='buspassword',
            database='kolkata_bus_db',
            charset='utf8mb4',
            autocommit=False
        )
    except Exception as e:
        print(f"Fallback to unix socket wbsoumo: {e}")
        conn = pymysql.connect(
            user='wbsoumo',
            unix_socket='/tmp/mysql.sock',
            database='kolkata_bus_db',
            charset='utf8mb4',
            autocommit=False
        )

    cursor = conn.cursor()

    # Recreate tables to have clean state
    print("Setting up schema...")
    cursor.execute("DROP TABLE IF EXISTS route_stops;")
    cursor.execute("DROP TABLE IF EXISTS stops;")
    cursor.execute("DROP TABLE IF EXISTS routes;")

    cursor.execute("""
    CREATE TABLE routes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        route_no VARCHAR(100) NOT NULL,
        route_name VARCHAR(255) NOT NULL,
        origin VARCHAR(255) NOT NULL,
        destination VARCHAR(255) NOT NULL,
        category VARCHAR(100) NOT NULL,
        bus_type VARCHAR(100) DEFAULT 'Standard',
        timetable TEXT,
        image_url VARCHAR(255),
        total_stops INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_route_no (route_no),
        INDEX idx_origin (origin),
        INDEX idx_destination (destination),
        INDEX idx_category (category)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    """)

    cursor.execute("""
    CREATE TABLE route_stops (
        id INT AUTO_INCREMENT PRIMARY KEY,
        route_id INT NOT NULL,
        stop_order INT NOT NULL,
        stop_name VARCHAR(255) NOT NULL,
        stop_clean VARCHAR(255) NOT NULL,
        INDEX idx_route_id (route_id),
        INDEX idx_stop_clean (stop_clean),
        INDEX idx_route_order (route_id, stop_order),
        CONSTRAINT fk_route FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    """)

    cursor.execute("""
    CREATE TABLE stops (
        id INT AUTO_INCREMENT PRIMARY KEY,
        stop_name VARCHAR(255) UNIQUE NOT NULL,
        routes_count INT DEFAULT 0,
        INDEX idx_stop_name (stop_name)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    """)

    files = [
        ('raw_data/routes1.js', 'Kolkata & Suburbs'),
        ('raw_data/routes2.js', 'NBSTC'),
        ('raw_data/routes3.js', 'SBSTC'),
        ('raw_data/routes4.js', 'Bardhaman & Nadia')
    ]

    stop_counts = {}
    inserted_routes = 0
    inserted_stops = 0

    route_insert_sql = """
    INSERT INTO routes (route_no, route_name, origin, destination, category, bus_type, timetable, image_url, total_stops)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    """

    stop_insert_sql = """
    INSERT INTO route_stops (route_id, stop_order, stop_name, stop_clean)
    VALUES (%s, %s, %s, %s)
    """

    for filepath, category in files:
        if not os.path.exists(filepath):
            print(f"Skipping {filepath} (not found)")
            continue
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        lines = re.findall(r'\"([^\"]+)\"', content)
        print(f"Processing {len(lines)} records from {filepath} [{category}]...")

        for line in lines:
            data = parse_entry(line, category)
            if not data:
                continue

            stops = data['stops']
            cursor.execute(route_insert_sql, (
                data['route_no'],
                data['route_name'],
                data['origin'],
                data['destination'],
                data['category'],
                data['bus_type'],
                data['timetable'],
                data['image_url'],
                len(stops)
            ))
            route_id = cursor.lastrowid
            inserted_routes += 1

            for idx, stop_name in enumerate(stops, start=1):
                clean_name = stop_name.strip()
                normalized = clean_name.lower()
                cursor.execute(stop_insert_sql, (route_id, idx, clean_name, normalized))
                inserted_stops += 1

                stop_counts[clean_name] = stop_counts.get(clean_name, 0) + 1

    print(f"Inserting {len(stop_counts)} unique stops into stops table...")
    stop_master_sql = """
    INSERT INTO stops (stop_name, routes_count) 
    VALUES (%s, %s) 
    ON DUPLICATE KEY UPDATE routes_count = routes_count + VALUES(routes_count)
    """
    cursor.executemany(stop_master_sql, [(name, count) for name, count in stop_counts.items()])

    conn.commit()
    cursor.close()
    conn.close()

    print(f"SUCCESS: Ingested {inserted_routes} routes, {inserted_stops} route stops, and {len(stop_counts)} unique master stops into MySQL!")

if __name__ == '__main__':
    main()
