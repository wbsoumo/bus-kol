<?php
/**
 * CholoKolkata (চলো কলকাতা) • Unified Production Transit API Engine
 * Handles all Bus, Metro, Live Tracking, and Community Chat Endpoints.
 * Compatible with 256-bit AES-GCM transit encryption.
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// 256-bit AES-GCM Transit Security Key
define('TRANSIT_SECURITY_KEY', 'KolkataTransitSecureKey2026WIMT!');

function secure_encrypt($payload) {
    $json = json_encode($payload, JSON_UNESCAPED_UNICODE);
    $key = TRANSIT_SECURITY_KEY;
    $nonce = openssl_random_pseudo_bytes(12);
    $tag = '';
    $ciphertext = openssl_encrypt($json, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $nonce, $tag, '', 16);
    return ['p' => base64_encode($nonce . $ciphertext . $tag)];
}

function get_db() {
    $host = 'localhost';
    $user = 'helnovexaa_bus';
    $pass = 'Soumojit1234@';
    $dbname = 'helnovexaa_buskolkata';

    $conn = mysqli_init();
    $conn->options(MYSQLI_OPT_INT_AND_FLOAT_NATIVE, 1);
    $connected = @$conn->real_connect($host, $user, $pass, $dbname);
    if (!$connected) {
        // Fallback for local testing
        $connected = @$conn->real_connect('127.0.0.1', 'root', '', 'kolkata_bus_db');
    }
    if (!$connected) {
        echo json_encode(secure_encrypt(['success' => false, 'error' => 'Database connection failed']));
        exit;
    }
    $conn->set_charset('utf8mb4');
    return $conn;
}

function calculate_bus_fare($bus_type, $total_stops) {
    $stops = max(1, (int)$total_stops);
    $type = strtolower($bus_type ?? '');
    if (strpos($type, 'ac') !== false || strpos($type, 'volvo') !== false) {
        if ($stops <= 5) return 25;
        if ($stops <= 12) return 35;
        if ($stops <= 20) return 45;
        return 60;
    }
    if ($stops <= 4) return 10;
    if ($stops <= 8) return 12;
    if ($stops <= 14) return 15;
    if ($stops <= 20) return 18;
    return 20;
}

function calculate_metro_fare($distance_km) {
    if ($distance_km <= 2.0) return 5;
    if ($distance_km <= 5.0) return 10;
    if ($distance_km <= 10.0) return 15;
    if ($distance_km <= 20.0) return 20;
    if ($distance_km <= 25.0) return 25;
    return 30;
}

function clean_search_term($term) {
    if (!$term) return '';
    $term = preg_replace('/\s*\([^)]*\)\s*/', ' ', $term);
    $term = trim(strtolower($term));
    $aliases = [
        'sector 5' => 'sector v',
        'sector-5' => 'sector v',
        'saltlake' => 'sector v',
        'salt lake' => 'sector v',
        'howrah stn' => 'howrah',
        'howrah station' => 'howrah',
        'sealdah station' => 'sealdah',
        'sealdah stn' => 'sealdah',
        'airport' => 'nsch airport'
    ];
    return $aliases[$term] ?? $term;
}

// Parse Route Request URL
$uri = $_SERVER['REQUEST_URI'];
$parsed_url = parse_url($uri, PHP_URL_PATH);
$route = trim(str_replace('/api/', '', $parsed_url), '/');
if (isset($_GET['endpoint'])) {
    $route = trim($_GET['endpoint'], '/');
}

// -------------------------------------------------------------
// 1. BUS SEARCH & MULTI-HOP 1-TRANSFER FINDER
// -------------------------------------------------------------
if ($route === 'search' || $route === 'routes') {
    $db = get_db();
    $from = trim($_GET['from'] ?? '');
    $to = trim($_GET['to'] ?? '');
    $bus_no = trim($_GET['bus_no'] ?? ($_GET['q'] ?? ''));
    $limit = min((int)($_GET['limit'] ?? 80), 100);

    // Direct search by Bus Number
    if ($bus_no || ($from && !$to)) {
        $term = $bus_no ? $bus_no : $from;
        $clean = clean_search_term($term);
        $no_hyphen = preg_replace('/[\s\-]+/', '', $term);

        $stmt = $db->prepare("
            SELECT id, route_no, route_name, origin, destination, category, bus_type, timetable, image_url, total_stops 
            FROM routes 
            WHERE route_no LIKE ? OR route_no LIKE ? OR REPLACE(route_no, '-', '') LIKE ? OR route_name LIKE ?
            ORDER BY LENGTH(route_no) ASC, route_no ASC LIMIT ?
        ");
        $t1 = "%$term%";
        $t2 = "%$clean%";
        $t3 = "%$no_hyphen%";
        $stmt->bind_param('ssssi', $t1, $t2, $t3, $t1, $limit);
        $stmt->execute();
        $res = $stmt->get_result();
        $routes = [];
        while ($r = $res->fetch_assoc()) {
            $fare = calculate_bus_fare($r['bus_type'], $r['total_stops']);
            $r['estimated_fare'] = $fare;
            $r['fare_text'] = "₹$fare";
            $routes[] = $r;
        }
        echo json_encode(secure_encrypt(['success' => true, 'count' => count($routes), 'routes' => $routes]));
        exit;
    }

    // Direct Stop to Stop Search
    if ($from && $to) {
        $from_clean = clean_search_term($from);
        $to_clean = clean_search_term($to);

        $stmt = $db->prepare("
            SELECT r.id, r.route_no, r.route_name, r.origin, r.destination, r.category, r.bus_type, r.timetable, r.image_url, r.total_stops,
                   f.stop_order AS from_order, f.stop_name AS from_stop_name,
                   t.stop_order AS to_order, t.stop_name AS to_stop_name
            FROM route_stops f
            JOIN route_stops t ON f.route_id = t.route_id
            JOIN routes r ON f.route_id = r.id
            WHERE f.stop_clean LIKE ? AND t.stop_clean LIKE ? AND f.stop_order < t.stop_order
            ORDER BY (t.stop_order - f.stop_order) ASC LIMIT ?
        ");
        $f_term = "%$from_clean%";
        $t_term = "%$to_clean%";
        $stmt->bind_param('ssi', $f_term, $t_term, $limit);
        $stmt->execute();
        $res = $stmt->get_result();
        $direct_routes = [];
        while ($r = $res->fetch_assoc()) {
            $stops_count = max(1, $r['to_order'] - $r['from_order']);
            $fare = calculate_bus_fare($r['bus_type'], $stops_count);
            $r['stops_between'] = $stops_count;
            $r['estimated_fare'] = $fare;
            $r['fare_text'] = "₹$fare";
            $r['est_time_mins'] = round($stops_count * 3.5);
            $direct_routes[] = $r;
        }

        // If direct exists, return direct routes
        if (!empty($direct_routes)) {
            echo json_encode(secure_encrypt([
                'success' => true,
                'type' => 'direct',
                'count' => count($direct_routes),
                'routes' => $direct_routes
            ]));
            exit;
        }

        // Otherwise: Multi-hop 1-Transfer Route Finder (via transit hubs)
        $hubs = ['Howrah', 'Esplanade', 'Ultadanga', 'Sealdah', 'Sector V', 'Ruby', 'Gariahat', 'Exide'];
        $transfers = [];

        foreach ($hubs as $hub) {
            $hub_clean = clean_search_term($hub);
            if ($hub_clean === $from_clean || $hub_clean === $to_clean) continue;

            // Leg 1
            $s1 = $db->prepare("
                SELECT r.id, r.route_no, r.route_name, r.bus_type, f.stop_order AS f_ord, t.stop_order AS t_ord 
                FROM route_stops f JOIN route_stops t ON f.route_id = t.route_id JOIN routes r ON f.route_id = r.id
                WHERE f.stop_clean LIKE ? AND t.stop_clean LIKE ? AND f.stop_order < t.stop_order LIMIT 1
            ");
            $h_term = "%$hub_clean%";
            $s1->bind_param('ss', $f_term, $h_term);
            $s1->execute();
            $leg1 = $s1->get_result()->fetch_assoc();

            if ($leg1) {
                // Leg 2
                $s2 = $db->prepare("
                    SELECT r.id, r.route_no, r.route_name, r.bus_type, f.stop_order AS f_ord, t.stop_order AS t_ord 
                    FROM route_stops f JOIN route_stops t ON f.route_id = t.route_id JOIN routes r ON f.route_id = r.id
                    WHERE f.stop_clean LIKE ? AND t.stop_clean LIKE ? AND f.stop_order < t.stop_order LIMIT 1
                ");
                $s2->bind_param('ss', $h_term, $t_term);
                $s2->execute();
                $leg2 = $s2->get_result()->fetch_assoc();

                if ($leg2) {
                    $fare1 = calculate_bus_fare($leg1['bus_type'], max(1, $leg1['t_ord'] - $leg1['f_ord']));
                    $fare2 = calculate_bus_fare($leg2['bus_type'], max(1, $leg2['t_ord'] - $leg2['f_ord']));
                    $transfers[] = [
                        'transfer_station' => $hub,
                        'total_fare' => $fare1 + $fare2,
                        'total_stops' => ($leg1['t_ord'] - $leg1['f_ord']) + ($leg2['t_ord'] - $leg2['f_ord']),
                        'leg1' => [
                            'route_no' => $leg1['route_no'],
                            'from_station' => $from,
                            'to_station' => $hub,
                            'fare' => $fare1
                        ],
                        'leg2' => [
                            'route_no' => $leg2['route_no'],
                            'from_station' => $hub,
                            'to_station' => $to,
                            'fare' => $fare2
                        ]
                    ];
                }
            }
        }

        echo json_encode(secure_encrypt([
            'success' => true,
            'type' => 'transfer',
            'count' => count($transfers),
            'transfers' => $transfers,
            'routes' => []
        ]));
        exit;
    }
}

// -------------------------------------------------------------
// 2. STOP AUTOCOMPLETE SEARCH
// -------------------------------------------------------------
if ($route === 'stops/search' || $route === 'stops') {
    $db = get_db();
    $q = trim($_GET['q'] ?? '');
    if (strlen($q) === 0) {
        $res = $db->query("SELECT stop_name, routes_count FROM stops ORDER BY routes_count DESC, LENGTH(stop_name) ASC LIMIT 15");
        $stops = [];
        while ($s = $res->fetch_assoc()) {
            $stops[] = $s;
        }
        echo json_encode(secure_encrypt(['success' => true, 'stops' => $stops]));
        exit;
    }
    $clean = clean_search_term($q);
    $stmt = $db->prepare("
        SELECT stop_name, routes_count 
        FROM stops 
        WHERE stop_name LIKE ? 
        ORDER BY (stop_name LIKE ?) DESC, routes_count DESC, LENGTH(stop_name) ASC 
        LIMIT 20
    ");
    $prefix = "$clean%";
    $term = "%$clean%";
    $stmt->bind_param('ss', $term, $prefix);
    $stmt->execute();
    $res = $stmt->get_result();
    $stops = [];
    while ($s = $res->fetch_assoc()) {
        $stops[] = $s;
    }
    echo json_encode(secure_encrypt(['success' => true, 'stops' => $stops]));
    exit;
}

// -------------------------------------------------------------
// 3. ROUTE DETAILS & STOPS
// -------------------------------------------------------------
if (preg_match('#^routes/(\d+)$#', $route, $m)) {
    $db = get_db();
    $route_id = (int)$m[1];
    $stmt = $db->prepare("SELECT * FROM routes WHERE id = ?");
    $stmt->bind_param('i', $route_id);
    $stmt->execute();
    $route_data = $stmt->get_result()->fetch_assoc();
    if (!$route_data) {
        echo json_encode(secure_encrypt(['success' => false, 'error' => 'Not found']));
        exit;
    }

    $st_stmt = $db->prepare("SELECT stop_order, stop_name FROM route_stops WHERE route_id = ? ORDER BY stop_order ASC");
    $st_stmt->bind_param('i', $route_id);
    $st_stmt->execute();
    $stops_res = $st_stmt->get_result();
    $stops = [];
    while ($row = $stops_res->fetch_assoc()) {
        $stops[] = $row;
    }
    $route_data['stops'] = $stops;
    $route_data['estimated_fare'] = calculate_bus_fare($route_data['bus_type'], count($stops));
    $route_data['fare_text'] = "₹" . $route_data['estimated_fare'];

    echo json_encode(secure_encrypt(['success' => true, 'route' => $route_data, 'stops' => $stops]));
    exit;
}

// -------------------------------------------------------------
// 4. METRO LINES & STATIONS
// -------------------------------------------------------------
if ($route === 'metro/lines') {
    $db = get_db();
    $res = $db->query("SELECT * FROM metro_lines ORDER BY line_number ASC");
    $lines = [];
    while ($row = $res->fetch_assoc()) {
        $lines[] = $row;
    }
    echo json_encode(secure_encrypt(['success' => true, 'lines' => $lines]));
    exit;
}

if ($route === 'metro/stations') {
    $db = get_db();
    $res = $db->query("SELECT s.*, l.line_name, l.line_color FROM metro_stations s JOIN metro_lines l ON s.line_id = l.line_id ORDER BY s.line_id, s.station_order ASC");
    $stations = [];
    while ($row = $res->fetch_assoc()) {
        $stations[] = $row;
    }
    echo json_encode(secure_encrypt(['success' => true, 'stations' => $stations]));
    exit;
}

// -------------------------------------------------------------
// 5. METRO ROUTE & FARE PLANNER
// -------------------------------------------------------------
if ($route === 'metro/plan') {
    $db = get_db();
    $from = trim($_GET['from'] ?? '');
    $to = trim($_GET['to'] ?? '');

    $s1 = $db->prepare("SELECT * FROM metro_stations WHERE station_name = ? LIMIT 1");
    $s1->bind_param('s', $from);
    $s1->execute();
    $stn1 = $s1->get_result()->fetch_assoc();

    $s2 = $db->prepare("SELECT * FROM metro_stations WHERE station_name = ? LIMIT 1");
    $s2->bind_param('s', $to);
    $s2->execute();
    $stn2 = $s2->get_result()->fetch_assoc();

    if (!$stn1 || !$stn2) {
        echo json_encode(secure_encrypt(['success' => false, 'error' => 'Station not found']));
        exit;
    }

    $same_line = ($stn1['line_id'] === $stn2['line_id']);
    $dist = abs((float)$stn1['distance_km'] - (float)$stn2['distance_km']);
    $fare = calculate_metro_fare($dist);
    $stations_count = abs((int)$stn1['station_order'] - (int)$stn2['station_order']) + 1;

    // Fetch intermediate stations
    $low = min((int)$stn1['station_order'], (int)$stn2['station_order']);
    $high = max((int)$stn1['station_order'], (int)$stn2['station_order']);
    $inter_stmt = $db->prepare("
        SELECT s.station_name, s.station_bengali, s.line_id, l.line_name, l.line_color, s.distance_km, s.interchange_info 
        FROM metro_stations s 
        JOIN metro_lines l ON s.line_id = l.line_id 
        WHERE s.line_id = ? AND s.station_order BETWEEN ? AND ? 
        ORDER BY s.station_order ASC
    ");
    $inter_stmt->bind_param('sii', $stn1['line_id'], $low, $high);
    $inter_stmt->execute();
    $inter_res = $inter_stmt->get_result();
    $path = [];
    while ($p = $inter_res->fetch_assoc()) {
        $p['distance_km'] = (float)$p['distance_km'];
        $path[] = $p;
    }
    if ((int)$stn1['station_order'] > (int)$stn2['station_order']) {
        $path = array_reverse($path);
    }

    $plan = [
        'type' => $same_line ? 'DIRECT' : 'INTERCHANGE',
        'from_station' => $from,
        'to_station' => $to,
        'fare' => (int)$fare,
        'fare_text' => "₹$fare",
        'stations_count' => (int)$stations_count,
        'distance_km' => round((float)$dist, 2),
        'duration_mins' => round((float)$stations_count * 2.2),
        'line_name' => $stn1['line_name'] ?? 'Metro Corridor',
        'line_color' => $stn1['line_color'] ?? '#00897B',
        'stations' => $path
    ];

    echo json_encode(secure_encrypt(['success' => true, 'plan' => $plan]));
    exit;
}

// -------------------------------------------------------------
// 6. LIVE COMMUTER BUS TRACKER & PINGS
// -------------------------------------------------------------
$cache_file = dirname(__FILE__) . '/tmp/live_buses.json';
if (!is_dir(dirname($cache_file))) {
    @mkdir(dirname($cache_file), 0755, true);
}

if ($route === 'bus/ping' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true) ?? [];
    $route_no = strtoupper(str_replace([' ', '-'], '', $data['route_no'] ?? ''));
    $lat = (float)($data['lat'] ?? 0);
    $lng = (float)($data['lng'] ?? 0);
    $speed = (float)($data['speed_kmh'] ?? 20.0);

    // Silent anti-spoof filter (Kolkata bounding box)
    if ($lat >= 22.2 && $lat <= 22.9 && $lng >= 88.1 && $lng <= 88.7 && $speed <= 85.0 && $route_no) {
        $store = file_exists($cache_file) ? json_decode(file_get_contents($cache_file), true) : [];
        if (!is_array($store)) $store = [];
        
        $now = time();
        $buses = $store[$route_no] ?? [];
        // Prune older than 75 seconds
        $valid = [];
        foreach ($buses as $b) {
            if ($now - $b['last_updated'] < 75) {
                $valid[] = $b;
            }
        }
        $valid[] = [
            'bus_id' => 'bus_' . $now,
            'lat' => $lat,
            'lng' => $lng,
            'speed_kmh' => $speed,
            'last_updated' => $now,
            'confidence' => 'HIGH'
        ];
        $store[$route_no] = $valid;
        file_put_contents($cache_file, json_encode($store));
    }
    echo json_encode(secure_encrypt(['success' => true, 'status' => 'received']));
    exit;
}

if (preg_match('#^bus/(.+)/live$#', $route, $m)) {
    $req_route = strtoupper(str_replace([' ', '-'], '', $m[1]));
    $store = file_exists($cache_file) ? json_decode(file_get_contents($cache_file), true) : [];
    $buses = $store[$req_route] ?? [];
    $now = time();
    $active = [];
    foreach ($buses as $b) {
        if ($now - $b['last_updated'] < 75) {
            $active[] = $b;
        }
    }
    echo json_encode(secure_encrypt(['success' => true, 'route_no' => $m[1], 'count' => count($active), 'active_buses' => $active]));
    exit;
}

if ($route === 'bus/live/stats') {
    $store = file_exists($cache_file) ? json_decode(file_get_contents($cache_file), true) : [];
    $now = time();
    $total = 0;
    $routes_cnt = 0;
    foreach ($store as $k => $list) {
        $valid_cnt = 0;
        foreach ($list as $b) {
            if ($now - $b['last_updated'] < 75) $valid_cnt++;
        }
        if ($valid_cnt > 0) {
            $total += $valid_cnt;
            $routes_cnt++;
        }
    }
    echo json_encode(secure_encrypt(['success' => true, 'stats' => ['total_live_buses' => $total, 'active_routes_count' => $routes_cnt]]));
    exit;
}

// -------------------------------------------------------------
// 7. COMMUTER COMMUNITY CHAT
// -------------------------------------------------------------
if ($route === 'chat/list' || $route === 'chat/messages') {
    $db = get_db();
    $channel = trim($_GET['channel'] ?? 'general');
    $limit = min(intval($_GET['limit'] ?? 40), 100);
    if ($limit <= 0) $limit = 40;

    if ($channel === 'general' || empty($channel)) {
        $stmt = $db->prepare("SELECT id, channel, user_name, route_ref, status_tag, message, DATE_FORMAT(created_at, '%h:%i %p') as time_str, created_at FROM community_chat WHERE channel = 'general' ORDER BY id DESC LIMIT ?");
        $stmt->bind_param('i', $limit);
    } else {
        $stmt = $db->prepare("SELECT id, channel, user_name, route_ref, status_tag, message, DATE_FORMAT(created_at, '%h:%i %p') as time_str, created_at FROM community_chat WHERE channel = ? OR channel = 'general' ORDER BY id DESC LIMIT ?");
        $stmt->bind_param('si', $channel, $limit);
    }
    $stmt->execute();
    $res = $stmt->get_result();
    $messages = [];
    while ($m = $res->fetch_assoc()) {
        $messages[] = $m;
    }
    echo json_encode(secure_encrypt(['success' => true, 'channel' => $channel, 'messages' => array_reverse($messages)]));
    exit;
}

if ($route === 'chat/post' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $db = get_db();
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true) ?? [];
    $channel = trim($data['channel'] ?? 'general');
    $user = trim($data['user_name'] ?? '');
    if (empty($user) || strtolower($user) === 'commuter' || strtolower($user) === 'passenger') {
        $rand_num = rand(10000, 99999);
        $user = "Passenger_$rand_num";
    }
    $msg = trim($data['message'] ?? '');
    $route_ref = trim($data['route_ref'] ?? '');
    $status_tag = trim($data['status_tag'] ?? 'Normal');

    if ($msg) {
        $stmt = $db->prepare("INSERT INTO community_chat (channel, user_name, route_ref, status_tag, message) VALUES (?, ?, ?, ?, ?)");
        $stmt->bind_param('sssss', $channel, $user, $route_ref, $status_tag, $msg);
        $stmt->execute();
        $msg_id = $stmt->insert_id;
        echo json_encode(secure_encrypt(['success' => true, 'id' => $msg_id, 'user_name' => $user]));
        exit;
    }
    echo json_encode(secure_encrypt(['success' => false, 'error' => 'Message required']));
    exit;
}

// -------------------------------------------------------------
// 8. BACKGROUND OTA UPDATE CHECK & SYNC
// -------------------------------------------------------------
if ($route === 'ota/check' || $route === 'sync') {
    $client_v = $_GET['version'] ?? '2.4.0';
    $vfile = __DIR__ . '/ota_version.json';
    $v = '2.4.0';
    $has_update = false;
    $changelog = 'Kolkata bus route database synced via OTA.';
    if (file_exists($vfile)) {
        $vdata = json_decode(file_get_contents($vfile), true);
        if (!empty($vdata['version'])) {
            $v = $vdata['version'];
            if ($client_v !== $v) {
                $has_update = true;
                $changelog = $vdata['changelog'] ?? $changelog;
            }
        }
    }
    echo json_encode(secure_encrypt([
        'success' => true,
        'version' => $v,
        'has_updates' => $has_update,
        'changelog' => $changelog
    ]));
    exit;
}

// -------------------------------------------------------------
// 9. ADMIN API: ADD ROUTE VIA REST API
// -------------------------------------------------------------
if ($route === 'admin/route/add' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true) ?? $_POST;
    $pass = $data['api_key'] ?? $data['passcode'] ?? '';
    if (preg_match('/Bearer\s+(.*)$/i', $auth, $m)) $pass = $m[1];

    if ($pass !== 'cholo2026admin' && $pass !== 'cholo2026') {
        echo json_encode(['success' => false, 'error' => 'Unauthorized admin access']);
        exit;
    }

    $db = get_db();
    $r_no = trim($data['route_no'] ?? '');
    $orig = trim($data['origin'] ?? '');
    $dest = trim($data['destination'] ?? '');
    $b_type = trim($data['bus_type'] ?? 'City Bus');
    $cat = trim($data['category'] ?? 'West Bengal Transport Corporation');
    $tt = trim($data['timetable'] ?? 'Runs daily 06:00 AM - 09:30 PM');
    $img = trim($data['image_url'] ?? '');
    $stops = $data['stops'] ?? [];

    if (empty($r_no) || empty($orig) || empty($dest)) {
        echo json_encode(['success' => false, 'error' => 'route_no, origin, destination are required']);
        exit;
    }

    if (is_string($stops)) {
        $stops = preg_split('/[,\r\n]+/', $stops);
    }
    $stops = array_values(array_filter(array_map('trim', $stops)));
    if (empty($stops) || $stops[0] !== $orig) array_unshift($stops, $orig);
    if (end($stops) !== $dest) $stops[] = $dest;

    $r_name = "$orig ➔ $dest";
    $tot = count($stops);

    $stmt = $db->prepare("INSERT INTO routes (route_no, route_name, origin, destination, category, bus_type, timetable, image_url, total_stops) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $stmt->bind_param("ssssssssi", $r_no, $r_name, $orig, $dest, $cat, $b_type, $tt, $img, $tot);
    if (!$stmt->execute()) {
        echo json_encode(['success' => false, 'error' => $db->error]);
        exit;
    }
    $route_id = $stmt->insert_id;

    $s_stmt = $db->prepare("INSERT INTO route_stops (route_id, stop_order, stop_name, stop_clean) VALUES (?, ?, ?, ?)");
    $m_stmt = $db->prepare("INSERT INTO stops (stop_name, routes_count) VALUES (?, 1) ON DUPLICATE KEY UPDATE routes_count = routes_count + 1");

    foreach ($stops as $idx => $sname) {
        $order = $idx + 1;
        $clean = strtolower($sname);
        $s_stmt->bind_param("iiss", $route_id, $order, $sname, $clean);
        $s_stmt->execute();
        $m_stmt->bind_param("s", $sname);
        $m_stmt->execute();
    }

    echo json_encode([
        'success' => true,
        'message' => "Route $r_no successfully created with $tot stops",
        'route_id' => $route_id,
        'total_stops' => $tot
    ]);
    exit;
}

// Default Fallback
echo json_encode(secure_encrypt(['success' => true, 'api' => 'CholoKolkata Transit API 2.4.0']));
exit;

