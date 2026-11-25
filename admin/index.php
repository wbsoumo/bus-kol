<?php
/**
 * CholoKolkata (চলো কলকাতা) • Web Admin Dashboard & Transit Management Portal
 * Allows transit administrators to add, edit, or delete bus routes and stops.
 * Changes take effect immediately across all mobile apps without requiring an app update.
 */

session_start();

// Admin Authentication Passcode
define('ADMIN_PASSCODE', 'cholo2026admin');
define('ADMIN_PASSCODE_ALT', 'cholo2026');

// Database Connection
function get_admin_db() {
    $host = 'localhost';
    $user = 'helnovexaa_bus';
    $pass = 'Soumojit1234@';
    $dbname = 'helnovexaa_buskolkata';

    $conn = mysqli_init();
    $conn->options(MYSQLI_OPT_INT_AND_FLOAT_NATIVE, 1);
    $connected = @$conn->real_connect($host, $user, $pass, $dbname);
    if (!$connected) {
        $connected = @$conn->real_connect('127.0.0.1', 'root', '', 'kolkata_bus_db');
    }
    if ($connected) {
        $conn->set_charset('utf8mb4');
    }
    return $connected ? $conn : null;
}

// Check Authentication Status
$is_authenticated = false;
if (isset($_SESSION['cholo_admin_logged']) && $_SESSION['cholo_admin_logged'] === true) {
    $is_authenticated = true;
}

// Bearer Token Authentication for external API calls
$auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
if (!empty($auth_header) && preg_match('/Bearer\s+(.*)$/i', $auth_header, $matches)) {
    if ($matches[1] === ADMIN_PASSCODE || $matches[1] === ADMIN_PASSCODE_ALT) {
        $is_authenticated = true;
    }
}

// -----------------------------------------------------------------------------
// POST / AJAX ACTIONS ROUTER
// -----------------------------------------------------------------------------
$action = $_REQUEST['action'] ?? '';

// 1. Login Action
if ($action === 'login' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $entered_pass = trim($_POST['passcode'] ?? '');
    if ($entered_pass === ADMIN_PASSCODE || $entered_pass === ADMIN_PASSCODE_ALT) {
        $_SESSION['cholo_admin_logged'] = true;
        header('Location: /admin');
        exit;
    } else {
        $login_error = "Invalid passcode. Please enter the authorized administrator key.";
    }
}

// 2. Logout Action
if ($action === 'logout') {
    $_SESSION['cholo_admin_logged'] = false;
    session_destroy();
    header('Location: /admin');
    exit;
}

// Require auth for all subsequent actions
if (!$is_authenticated && !empty($action)) {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['success' => false, 'error' => 'Unauthorized. Please log in first.']);
    exit;
}

function admin_bump_ota_version($changelog = null) {
    $version_file = __DIR__ . '/../ota_version.json';
    $current_v = '2.4.0';
    if (file_exists($version_file)) {
        $vdata = json_decode(file_get_contents($version_file), true);
        if (isset($vdata['version'])) $current_v = $vdata['version'];
    }
    $parts = explode('.', $current_v);
    if (count($parts) === 3) {
        $parts[2] = intval($parts[2]) + 1;
        $new_v = implode('.', $parts);
    } else {
        $new_v = '2.4.1';
    }
    $save_data = [
        'version' => $new_v,
        'has_updates' => true,
        'changelog' => $changelog ?: "New bus routes and transit schedules published by administrator (v$new_v).",
        'last_updated' => date('Y-m-d H:i:s T')
    ];
    @file_put_contents($version_file, json_encode($save_data, JSON_PRETTY_PRINT));
    return $new_v;
}

$db = get_admin_db();

// 3. API Action: Get Route Details with Stops Timeline
if ($action === 'get_route') {
    header('Content-Type: application/json; charset=utf-8');
    $route_id = intval($_GET['id'] ?? 0);
    if ($route_id <= 0 || !$db) {
        echo json_encode(['success' => false, 'error' => 'Invalid route ID']);
        exit;
    }

    $stmt = $db->prepare("SELECT * FROM routes WHERE id = ?");
    $stmt->bind_param("i", $route_id);
    $stmt->execute();
    $route = $stmt->get_result()->fetch_assoc();

    if (!$route) {
        echo json_encode(['success' => false, 'error' => 'Route not found']);
        exit;
    }

    $stmt2 = $db->prepare("SELECT stop_order, stop_name FROM route_stops WHERE route_id = ? ORDER BY stop_order ASC");
    $stmt2->bind_param("i", $route_id);
    $stmt2->execute();
    $res2 = $stmt2->get_result();
    $stops = [];
    while ($row = $res2->fetch_assoc()) {
        $stops[] = $row;
    }

    echo json_encode(['success' => true, 'route' => $route, 'stops' => $stops]);
    exit;
}

// 4. API Action: Add New Bus Route & Stops
if ($action === 'add_route' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    header('Content-Type: application/json; charset=utf-8');
    if (!$db) {
        echo json_encode(['success' => false, 'error' => 'Database connection unavailable']);
        exit;
    }

    $route_no = trim($_POST['route_no'] ?? '');
    $origin = trim($_POST['origin'] ?? '');
    $destination = trim($_POST['destination'] ?? '');
    $bus_type = trim($_POST['bus_type'] ?? 'City Bus');
    $category = trim($_POST['category'] ?? 'West Bengal Transport Corporation');
    $timetable = trim($_POST['timetable'] ?? 'Runs daily 06:00 AM - 09:30 PM (Every 10-15 mins)');
    $image_url = trim($_POST['image_url'] ?? '');
    $stops_raw = trim($_POST['stops'] ?? '');

    if (empty($route_no) || empty($origin) || empty($destination)) {
        echo json_encode(['success' => false, 'error' => 'Route Number, Origin, and Destination are required.']);
        exit;
    }

    // Parse stops list (supports comma-separated or newline-separated)
    $stops_list = [];
    if (!empty($stops_raw)) {
        $split = preg_split('/[,\r\n]+/', $stops_raw);
        foreach ($split as $s) {
            $cleaned = trim($s);
            if (!empty($cleaned) && !in_array($cleaned, $stops_list)) {
                $stops_list[] = $cleaned;
            }
        }
    }

    // Ensure origin is first and destination is last if missing
    if (!empty($origin) && (empty($stops_list) || $stops_list[0] !== $origin)) {
        array_unshift($stops_list, $origin);
    }
    if (!empty($destination) && (empty($stops_list) || end($stops_list) !== $destination)) {
        $stops_list[] = $destination;
    }

    $route_name = "$origin ➔ $destination";
    $total_stops = count($stops_list);

    // Insert Route
    $stmt = $db->prepare("INSERT INTO routes (route_no, route_name, origin, destination, category, bus_type, timetable, image_url, total_stops) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $stmt->bind_param("ssssssssi", $route_no, $route_name, $origin, $destination, $category, $bus_type, $timetable, $image_url, $total_stops);

    if (!$stmt->execute()) {
        echo json_encode(['success' => false, 'error' => 'Failed to insert route: ' . $db->error]);
        exit;
    }

    $route_id = $stmt->insert_id;

    // Insert Stops into route_stops and update master stops table
    $stop_stmt = $db->prepare("INSERT INTO route_stops (route_id, stop_order, stop_name, stop_clean) VALUES (?, ?, ?, ?)");
    $master_stop_stmt = $db->prepare("INSERT INTO stops (stop_name, routes_count) VALUES (?, 1) ON DUPLICATE KEY UPDATE routes_count = routes_count + 1");

    foreach ($stops_list as $order => $stop_name) {
        $idx = $order + 1;
        $stop_clean = strtolower($stop_name);
        $stop_stmt->bind_param("iiss", $route_id, $idx, $stop_name, $stop_clean);
        $stop_stmt->execute();

        $master_stop_stmt->bind_param("s", $stop_name);
        $master_stop_stmt->execute();
    }

    $new_v = admin_bump_ota_version("Added route $route_no ($origin ➔ $destination).");

    echo json_encode([
        'success' => true,
        'message' => "Route $route_no successfully published! $total_stops stops indexed (OTA v$new_v).",
        'route_id' => $route_id,
        'total_stops' => $total_stops,
        'ota_version' => $new_v
    ]);
    exit;
}

// 5. API Action: Edit Existing Route & Stops
if ($action === 'edit_route' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    header('Content-Type: application/json; charset=utf-8');
    if (!$db) {
        echo json_encode(['success' => false, 'error' => 'Database connection unavailable']);
        exit;
    }

    $route_id = intval($_POST['route_id'] ?? 0);
    $route_no = trim($_POST['route_no'] ?? '');
    $origin = trim($_POST['origin'] ?? '');
    $destination = trim($_POST['destination'] ?? '');
    $bus_type = trim($_POST['bus_type'] ?? 'City Bus');
    $category = trim($_POST['category'] ?? 'West Bengal Transport Corporation');
    $timetable = trim($_POST['timetable'] ?? '');
    $image_url = trim($_POST['image_url'] ?? '');
    $stops_raw = trim($_POST['stops'] ?? '');

    if ($route_id <= 0 || empty($route_no) || empty($origin) || empty($destination)) {
        echo json_encode(['success' => false, 'error' => 'Invalid parameters. Route number, origin, and destination are required.']);
        exit;
    }

    $stops_list = [];
    if (!empty($stops_raw)) {
        $split = preg_split('/[,\r\n]+/', $stops_raw);
        foreach ($split as $s) {
            $cleaned = trim($s);
            if (!empty($cleaned) && !in_array($cleaned, $stops_list)) {
                $stops_list[] = $cleaned;
            }
        }
    }

    if (!empty($origin) && (empty($stops_list) || $stops_list[0] !== $origin)) {
        array_unshift($stops_list, $origin);
    }
    if (!empty($destination) && (empty($stops_list) || end($stops_list) !== $destination)) {
        $stops_list[] = $destination;
    }

    $route_name = "$origin ➔ $destination";
    $total_stops = count($stops_list);

    // Update Route
    $stmt = $db->prepare("UPDATE routes SET route_no = ?, route_name = ?, origin = ?, destination = ?, category = ?, bus_type = ?, timetable = ?, image_url = ?, total_stops = ? WHERE id = ?");
    $stmt->bind_param("ssssssssii", $route_no, $route_name, $origin, $destination, $category, $bus_type, $timetable, $image_url, $total_stops, $route_id);

    if (!$stmt->execute()) {
        echo json_encode(['success' => false, 'error' => 'Update failed: ' . $db->error]);
        exit;
    }

    // Refresh route stops
    $del = $db->prepare("DELETE FROM route_stops WHERE route_id = ?");
    $del->bind_param("i", $route_id);
    $del->execute();

    $stop_stmt = $db->prepare("INSERT INTO route_stops (route_id, stop_order, stop_name, stop_clean) VALUES (?, ?, ?, ?)");
    $master_stop_stmt = $db->prepare("INSERT INTO stops (stop_name, routes_count) VALUES (?, 1) ON DUPLICATE KEY UPDATE routes_count = routes_count + 1");

    foreach ($stops_list as $order => $stop_name) {
        $idx = $order + 1;
        $stop_clean = strtolower($stop_name);
        $stop_stmt->bind_param("iiss", $route_id, $idx, $stop_name, $stop_clean);
        $stop_stmt->execute();

        $master_stop_stmt->bind_param("s", $stop_name);
        $master_stop_stmt->execute();
    }

    $new_v = admin_bump_ota_version("Updated route $route_no ($origin ➔ $destination).");

    echo json_encode([
        'success' => true,
        'message' => "Route $route_no updated successfully with $total_stops stops (OTA v$new_v)!",
        'route_id' => $route_id,
        'ota_version' => $new_v
    ]);
    exit;
}

// 6. API Action: Delete Route
if ($action === 'delete_route' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    header('Content-Type: application/json; charset=utf-8');
    if (!$db) {
        echo json_encode(['success' => false, 'error' => 'Database connection unavailable']);
        exit;
    }

    $route_id = intval($_POST['route_id'] ?? 0);
    if ($route_id <= 0) {
        echo json_encode(['success' => false, 'error' => 'Invalid route ID']);
        exit;
    }

    // ON DELETE CASCADE automatically removes route_stops
    $stmt = $db->prepare("DELETE FROM routes WHERE id = ?");
    $stmt->bind_param("i", $route_id);

    if ($stmt->execute()) {
        $new_v = admin_bump_ota_version("Removed bus route ID #$route_id.");
        echo json_encode(['success' => true, 'message' => "Route and its stops deleted successfully (OTA v$new_v).", 'ota_version' => $new_v]);
    } else {
        echo json_encode(['success' => false, 'error' => 'Delete failed: ' . $db->error]);
    }
    exit;
}

// 7. API Action: Publish / Bump OTA Sync Version
if ($action === 'bump_sync' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    header('Content-Type: application/json; charset=utf-8');
    $version_file = __DIR__ . '/../ota_version.json';
    $current_v = '2.4.0';
    if (file_exists($version_file)) {
        $vdata = json_decode(file_get_contents($version_file), true);
        if (isset($vdata['version'])) $current_v = $vdata['version'];
    }

    // Bump minor version
    $parts = explode('.', $current_v);
    if (count($parts) === 3) {
        $parts[2] = intval($parts[2]) + 1;
        $new_v = implode('.', $parts);
    } else {
        $new_v = '2.4.1';
    }

    $save_data = [
        'version' => $new_v,
        'has_updates' => true,
        'changelog' => "New bus routes and transit schedules published by administrator (v$new_v).",
        'last_updated' => date('Y-m-d H:i:s T')
    ];
    file_put_contents($version_file, json_encode($save_data, JSON_PRETTY_PRINT));

    echo json_encode([
        'success' => true,
        'version' => $new_v,
        'message' => "OTA sync broadcasted! Mobile apps will update to v$new_v silently."
    ]);
    exit;
}

// -----------------------------------------------------------------------------
// HTML DASHBOARD RENDERING
// -----------------------------------------------------------------------------

// Fetch Summary Stats
$stats = [
    'total_routes' => 0,
    'total_stops' => 0,
    'ac_routes' => 0,
    'metro_stations' => 50,
];

if ($db) {
    $r1 = $db->query("SELECT COUNT(*) AS c FROM routes");
    if ($r1 && $row = $r1->fetch_assoc()) $stats['total_routes'] = $row['c'];

    $r2 = $db->query("SELECT COUNT(*) AS c FROM stops");
    if ($r2 && $row = $r2->fetch_assoc()) $stats['total_stops'] = $row['c'];

    $r3 = $db->query("SELECT COUNT(*) AS c FROM routes WHERE bus_type LIKE '%AC%' OR route_no LIKE 'AC%'");
    if ($r3 && $row = $r3->fetch_assoc()) $stats['ac_routes'] = $row['c'];
}

// Search and Pagination for Routes
$active_tab = trim($_GET['tab'] ?? 'routes');
if (!in_array($active_tab, ['routes', 'analytics', 'chat'])) {
    $active_tab = 'routes';
}
$search_query = trim($_GET['q'] ?? '');
$filter_type = trim($_GET['type'] ?? '');
$page = max(1, intval($_GET['page'] ?? 1));
$per_page = 25;
$offset = ($page - 1) * $per_page;

// Analytics & Chat Logs Data
$analytics_summary = [
    'total_searches' => 0,
    'bus_searches' => 0,
    'metro_searches' => 0,
    'unique_devices' => 0,
];
$top_bus_corridors = [];
$top_bus_numbers = [];
$top_metro_corridors = [];
$top_search_locations = [];
$recent_searches_log = [];
$chat_logs = [];

if ($db && $is_authenticated) {
    $tbl_chk = @$db->query("SHOW TABLES LIKE 'search_analytics'");
    if ($tbl_chk && $tbl_chk->num_rows > 0) {
        if ($r = @$db->query("SELECT COUNT(*) AS total, SUM(search_mode IN ('bus_route','bus_no')) AS bus_cnt, SUM(search_mode = 'metro') AS metro_cnt, COUNT(DISTINCT NULLIF(device_id,'')) AS dev_cnt FROM search_analytics")) {
            $row = $r->fetch_assoc();
            $analytics_summary['total_searches'] = intval($row['total'] ?? 0);
            $analytics_summary['bus_searches'] = intval($row['bus_cnt'] ?? 0);
            $analytics_summary['metro_searches'] = intval($row['metro_cnt'] ?? 0);
            $analytics_summary['unique_devices'] = intval($row['dev_cnt'] ?? 0);
        }
        if ($active_tab === 'analytics') {
            if ($r = @$db->query("SELECT from_query, to_query, COUNT(*) AS hits FROM search_analytics WHERE search_mode = 'bus_route' AND from_query != '' AND to_query != '' GROUP BY from_query, to_query ORDER BY hits DESC LIMIT 15")) {
                while ($row = $r->fetch_assoc()) $top_bus_corridors[] = $row;
            }
            if ($r = @$db->query("SELECT bus_no, COUNT(*) AS hits FROM search_analytics WHERE search_mode = 'bus_no' AND bus_no != '' GROUP BY bus_no ORDER BY hits DESC LIMIT 15")) {
                while ($row = $r->fetch_assoc()) $top_bus_numbers[] = $row;
            }
            if ($r = @$db->query("SELECT from_query, to_query, COUNT(*) AS hits FROM search_analytics WHERE search_mode = 'metro' AND from_query != '' AND to_query != '' GROUP BY from_query, to_query ORDER BY hits DESC LIMIT 15")) {
                while ($row = $r->fetch_assoc()) $top_metro_corridors[] = $row;
            }
            if ($r = @$db->query("SELECT COALESCE(NULLIF(location_name,''), ip_address, 'Unknown') AS area, ip_address, COUNT(*) AS hits FROM search_analytics GROUP BY area, ip_address ORDER BY hits DESC LIMIT 15")) {
                while ($row = $r->fetch_assoc()) $top_search_locations[] = $row;
            }
            if ($r = @$db->query("SELECT search_mode, from_query, to_query, bus_no, results_count, location_name, latitude, longitude, ip_address, searched_at, created_at FROM search_analytics ORDER BY id DESC LIMIT 40")) {
                while ($row = $r->fetch_assoc()) $recent_searches_log[] = $row;
            }
        }
    }

    if ($active_tab === 'chat') {
        $col_chk = @$db->query("SHOW COLUMNS FROM community_chat LIKE 'ip_address'");
        if ($col_chk && $col_chk->num_rows > 0) {
            $r = @$db->query("SELECT id, channel, user_name, route_ref, status_tag, message, ip_address, latitude, longitude, location_name, created_at FROM community_chat ORDER BY id DESC LIMIT 100");
        } else {
            $r = @$db->query("SELECT id, channel, user_name, route_ref, status_tag, message, '' AS ip_address, NULL AS latitude, NULL AS longitude, '' AS location_name, created_at FROM community_chat ORDER BY id DESC LIMIT 100");
        }
        if ($r) {
            while ($row = $r->fetch_assoc()) $chat_logs[] = $row;
        }
    }
}

$routes_list = [];
$total_matching_routes = 0;

if ($db && $is_authenticated) {
    $where = [];
    $params = [];
    $types = '';

    if (!empty($search_query)) {
        $where[] = "(route_no LIKE ? OR origin LIKE ? OR destination LIKE ? OR route_name LIKE ?)";
        $sq = "%$search_query%";
        $params[] = $sq; $params[] = $sq; $params[] = $sq; $params[] = $sq;
        $types .= 'ssss';
    }

    if (!empty($filter_type)) {
        if ($filter_type === 'ac') {
            $where[] = "(bus_type LIKE '%AC%' OR route_no LIKE 'AC%')";
        } elseif ($filter_type === 'wbtc') {
            $where[] = "category LIKE '%Bengal%'";
        } elseif ($filter_type === 'private') {
            $where[] = "category LIKE '%Private%'";
        }
    }

    $where_sql = !empty($where) ? 'WHERE ' . implode(' AND ', $where) : '';

    // Count Total
    $count_sql = "SELECT COUNT(*) AS c FROM routes $where_sql";
    if (!empty($params)) {
        $cstmt = $db->prepare($count_sql);
        $cstmt->bind_param($types, ...$params);
        $cstmt->execute();
        $total_matching_routes = $cstmt->get_result()->fetch_assoc()['c'];
    } else {
        $r = $db->query($count_sql);
        if ($r && $row = $r->fetch_assoc()) $total_matching_routes = $row['c'];
    }

    // Fetch Paginated
    $query_sql = "SELECT * FROM routes $where_sql ORDER BY id DESC LIMIT ? OFFSET ?";
    $params[] = $per_page;
    $params[] = $offset;
    $types .= 'ii';

    $stmt = $db->prepare($query_sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $res = $stmt->get_result();
    while ($row = $res->fetch_assoc()) {
        $routes_list[] = $row;
    }
}

$total_pages = ceil($total_matching_routes / $per_page);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CholoKolkata • Transit Control Center & Route Manager</title>
    <!-- Tailwind CSS CDN -->
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Noto+Sans+Bengali:wght@500;700&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Plus Jakarta Sans', sans-serif; }
        .bengali { font-family: 'Noto Sans Bengali', sans-serif; }
        .glass-card { background: rgba(255, 255, 255, 0.95); backdrop-filter: blur(10px); }
        .royal-gradient { background: linear-gradient(135deg, #0050DA 0%, #0036B8 100%); }
        .tab-active { border-bottom: 3px solid #0050DA; color: #0050DA; font-weight: 700; }
    </style>
</head>
<body class="bg-slate-50 text-slate-800 min-h-screen">

<?php if (!$is_authenticated): ?>
<!-- ======================================================================= -->
<!-- LOGIN SCREEN -->
<!-- ======================================================================= -->
<div class="min-h-screen flex items-center justify-center p-4 bg-gradient-to-br from-blue-900 via-indigo-900 to-slate-900">
    <div class="max-w-md w-full glass-card rounded-2xl shadow-2xl p-8 border border-white/20">
        <div class="text-center mb-8">
            <div class="inline-flex items-center justify-center w-20 h-20 rounded-2xl royal-gradient shadow-lg shadow-blue-500/30 mb-4">
                <span class="text-3xl">🚌</span>
            </div>
            <h1 class="text-2xl font-black text-slate-900 tracking-tight">CholoKolkata Control</h1>
            <p class="text-xs text-blue-600 font-bold uppercase tracking-widest mt-1">Transit Admin Portal • চলো কলকাতা</p>
            <p class="text-xs text-slate-500 mt-2">Manage live bus routes, stops timeline, and schedules for Kolkata commuter mobile apps.</p>
        </div>

        <?php if (!empty($login_error)): ?>
        <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded-xl text-red-700 text-xs font-semibold flex items-center gap-2">
            <span>⚠️</span>
            <span><?= htmlspecialchars($login_error) ?></span>
        </div>
        <?php endif; ?>

        <form method="POST" action="/admin?action=login" class="space-y-4">
            <div>
                <label class="block text-xs font-bold text-slate-700 uppercase mb-2">Administrator Key</label>
                <div class="relative">
                    <input type="password" name="passcode" id="passcode" required autofocus placeholder="Enter admin passcode" 
                        class="w-full px-4 py-3 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm font-mono tracking-wider">
                    <button type="button" onclick="togglePass()" class="absolute right-3 top-3 text-slate-400 hover:text-slate-600 text-xs font-bold uppercase">Show</button>
                </div>
                <p class="text-[11px] text-slate-400 mt-1.5">Authorized dispatchers & transit database managers only.</p>
            </div>

            <button type="submit" class="w-full py-3 royal-gradient text-white font-bold rounded-xl shadow-lg shadow-blue-600/30 hover:opacity-95 transition-all text-sm">
                Unlock Dashboard ➔
            </button>
        </form>

        <div class="mt-8 pt-6 border-t border-slate-100 text-center text-xs text-slate-400">
            Made in Kolkata with Love of Rosogolla 🍮 • 2026
        </div>
    </div>
</div>

<script>
function togglePass() {
    const p = document.getElementById('passcode');
    p.type = p.type === 'password' ? 'text' : 'password';
}
</script>

<?php else: ?>
<!-- ======================================================================= -->
<!-- AUTHENTICATED DASHBOARD -->
<!-- ======================================================================= -->
<div class="min-h-screen flex flex-col">

    <!-- Top Navigation Bar -->
    <header class="bg-white border-b border-slate-200 sticky top-0 z-30 shadow-sm">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
            <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-xl royal-gradient flex items-center justify-center text-white shadow-md shadow-blue-500/20">
                    <span class="text-xl">🚌</span>
                </div>
                <div>
                    <div class="flex items-center gap-2">
                        <span class="font-extrabold text-slate-900 tracking-tight text-base">CholoKolkata</span>
                        <span class="px-2 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider bg-blue-100 text-blue-700">Admin</span>
                    </div>
                    <p class="text-[11px] text-slate-500 font-medium">Kolkata Bus & Metro Transit Management</p>
                </div>
            </div>

            <div class="flex items-center gap-3">
                <a href="/" target="_blank" class="hidden sm:inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-slate-600 bg-slate-100 rounded-lg hover:bg-slate-200 transition">
                    <span>🌐</span>
                    <span>View Public App</span>
                </a>
                <button onclick="triggerOtaBump()" class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-emerald-700 bg-emerald-50 border border-emerald-200 rounded-lg hover:bg-emerald-100 transition shadow-sm">
                    <span>🔄</span>
                    <span id="ota-btn-label">Publish OTA Sync</span>
                </button>
                <a href="/admin?action=logout" class="inline-flex items-center gap-1 px-3 py-1.5 text-xs font-bold text-red-600 bg-red-50 rounded-lg hover:bg-red-100 transition">
                    <span>Logout</span>
                </a>
            </div>
        </div>
    </header>

    <!-- Main Container -->
    <main class="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">

        <!-- Stat Cards Grid -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div class="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-sm">
                <div class="flex items-center justify-between">
                    <span class="text-xs font-bold text-slate-500 uppercase tracking-wider">Total Bus Routes</span>
                    <span class="p-2 bg-blue-50 text-blue-600 rounded-xl text-lg">🚍</span>
                </div>
                <div class="mt-3">
                    <span class="text-2xl font-black text-slate-900"><?= number_format($stats['total_routes']) ?></span>
                    <span class="text-xs text-emerald-600 font-bold ml-1.5">● Live</span>
                </div>
                <p class="text-[11px] text-slate-400 mt-1">Available across Android app & web</p>
            </div>

            <div class="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-sm">
                <div class="flex items-center justify-between">
                    <span class="text-xs font-bold text-slate-500 uppercase tracking-wider">Indexed Stops</span>
                    <span class="p-2 bg-amber-50 text-amber-600 rounded-xl text-lg">🛑</span>
                </div>
                <div class="mt-3">
                    <span class="text-2xl font-black text-slate-900"><?= number_format($stats['total_stops']) ?></span>
                    <span class="text-xs text-blue-600 font-bold ml-1.5">Auto-complete</span>
                </div>
                <p class="text-[11px] text-slate-400 mt-1">Kolkata & Howrah metropolitan area</p>
            </div>

            <div class="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-sm">
                <div class="flex items-center justify-between">
                    <span class="text-xs font-bold text-slate-500 uppercase tracking-wider">AC Fleet Routes</span>
                    <span class="p-2 bg-purple-50 text-purple-600 rounded-xl text-lg">⚡</span>
                </div>
                <div class="mt-3">
                    <span class="text-2xl font-black text-slate-900"><?= number_format($stats['ac_routes']) ?></span>
                    <span class="text-xs text-purple-600 font-bold ml-1.5">Electric & Volvo</span>
                </div>
                <p class="text-[11px] text-slate-400 mt-1">WBTC Green & AC Corridors</p>
            </div>

            <div class="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-sm">
                <div class="flex items-center justify-between">
                    <span class="text-xs font-bold text-slate-500 uppercase tracking-wider">Metro Stations</span>
                    <span class="p-2 bg-emerald-50 text-emerald-600 rounded-xl text-lg">🚇</span>
                </div>
                <div class="mt-3">
                    <span class="text-2xl font-black text-slate-900">50</span>
                    <span class="text-xs text-emerald-600 font-bold ml-1.5">4 Corridors</span>
                </div>
                <p class="text-[11px] text-slate-400 mt-1">Blue, Green, Purple, Orange</p>
            </div>
        </div>

        <!-- Navigation Tabs -->
        <div class="flex flex-wrap items-center gap-2 bg-white p-2 rounded-2xl border border-slate-200/80 shadow-sm">
            <a href="/admin?tab=routes" class="px-4 py-2 rounded-xl text-xs font-extrabold transition <?= $active_tab === 'routes' ? 'royal-gradient text-white shadow' : 'text-slate-600 hover:bg-slate-100' ?>">
                🚌 Bus Routes Directory
            </a>
            <a href="/admin?tab=analytics" class="px-4 py-2 rounded-xl text-xs font-extrabold transition <?= $active_tab === 'analytics' ? 'royal-gradient text-white shadow' : 'text-slate-600 hover:bg-slate-100' ?>">
                📊 Search Analytics (<?= number_format($analytics_summary['total_searches']) ?>)
            </a>
            <a href="/admin?tab=chat" class="px-4 py-2 rounded-xl text-xs font-extrabold transition <?= $active_tab === 'chat' ? 'royal-gradient text-white shadow' : 'text-slate-600 hover:bg-slate-100' ?>">
                💬 Chat IP & Location Logs
            </a>
        </div>

        <?php if ($active_tab === 'routes'): ?>
        <!-- Action Toolbar -->
        <div class="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-sm flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3">
            <!-- Search & Filters -->
            <form method="GET" action="/admin" class="flex-1 flex flex-col sm:flex-row items-stretch sm:items-center gap-2">
                <div class="relative flex-1">
                    <span class="absolute left-3 top-2.5 text-slate-400 text-sm">🔍</span>
                    <input type="text" name="q" value="<?= htmlspecialchars($search_query) ?>" placeholder="Search by route number (e.g. 215A), stop, or corridor..." 
                        class="w-full pl-9 pr-4 py-2 text-xs rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent font-medium">
                </div>
                <select name="type" onchange="this.form.submit()" class="px-3 py-2 text-xs rounded-xl border border-slate-200 bg-white font-medium text-slate-700 focus:outline-none">
                    <option value="">All Categories</option>
                    <option value="ac" <?= $filter_type === 'ac' ? 'selected' : '' ?>>⚡ AC & Electric Fleet</option>
                    <option value="wbtc" <?= $filter_type === 'wbtc' ? 'selected' : '' ?>>🏛️ WBTC State Buses</option>
                    <option value="private" <?= $filter_type === 'private' ? 'selected' : '' ?>>🚌 Private Bus Syndicates</option>
                </select>
                <button type="submit" class="px-4 py-2 bg-slate-900 text-white font-bold text-xs rounded-xl hover:bg-slate-800 transition">
                    Filter
                </button>
                <?php if (!empty($search_query) || !empty($filter_type)): ?>
                <a href="/admin" class="px-3 py-2 text-xs font-bold text-slate-500 hover:text-slate-700 text-center">Reset</a>
                <?php endif; ?>
            </form>

            <!-- Add Route Trigger Button -->
            <button onclick="openAddModal()" class="px-5 py-2.5 royal-gradient text-white text-xs font-extrabold rounded-xl shadow-lg shadow-blue-500/20 hover:opacity-95 transition flex items-center justify-center gap-2 shrink-0">
                <span class="text-sm font-black">+</span>
                <span>Add New Bus Route</span>
            </button>
        </div>

        <!-- Routes Table Container -->
        <div class="bg-white rounded-2xl border border-slate-200/80 shadow-sm overflow-hidden">
            <div class="px-6 py-4 border-b border-slate-100 flex items-center justify-between">
                <div>
                    <h2 class="font-extrabold text-slate-900 text-sm">Active Bus Routes Directory</h2>
                    <p class="text-xs text-slate-500">Showing <?= count($routes_list) ?> of <?= number_format($total_matching_routes) ?> routes registered in MySQL.</p>
                </div>
                <span class="text-xs text-slate-400 font-mono">Page <?= $page ?> of <?= max(1, $total_pages) ?></span>
            </div>

            <div class="overflow-x-auto">
                <table class="w-full text-left text-xs">
                    <thead class="bg-slate-50 text-slate-500 font-bold uppercase tracking-wider border-b border-slate-100">
                        <tr>
                            <th class="px-6 py-3.5">Route #</th>
                            <th class="px-6 py-3.5">Corridor / Terminals</th>
                            <th class="px-6 py-3.5">Bus Type & Operator</th>
                            <th class="px-6 py-3.5">Stops</th>
                            <th class="px-6 py-3.5 text-right">Actions</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-slate-100 font-medium">
                        <?php if (empty($routes_list)): ?>
                        <tr>
                            <td colspan="5" class="px-6 py-12 text-center text-slate-400">
                                <span class="text-3xl block mb-2">🔍</span>
                                No bus routes matched your search criteria.
                            </td>
                        </tr>
                        <?php endif; ?>

                        <?php foreach ($routes_list as $r): 
                            $is_ac = stripos($r['bus_type'], 'ac') !== false || stripos($r['route_no'], 'ac') !== false;
                        ?>
                        <tr class="hover:bg-blue-50/40 transition">
                            <!-- Route No -->
                            <td class="px-6 py-4">
                                <div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg font-black text-xs <?= $is_ac ? 'bg-purple-100 text-purple-800 border border-purple-200' : 'bg-blue-100 text-blue-900 border border-blue-200' ?>">
                                    <?php if ($is_ac): ?><span>⚡</span><?php endif; ?>
                                    <span><?= htmlspecialchars($r['route_no']) ?></span>
                                </div>
                            </td>

                            <!-- Corridor -->
                            <td class="px-6 py-4">
                                <div class="font-bold text-slate-900 text-xs flex items-center gap-1.5">
                                    <span><?= htmlspecialchars($r['origin']) ?></span>
                                    <span class="text-slate-400">➔</span>
                                    <span><?= htmlspecialchars($r['destination']) ?></span>
                                </div>
                                <div class="text-[11px] text-slate-400 truncate max-w-md mt-0.5"><?= htmlspecialchars($r['route_name']) ?></div>
                            </td>

                            <!-- Type & Operator -->
                            <td class="px-6 py-4">
                                <div class="text-slate-800 font-semibold"><?= htmlspecialchars($r['bus_type']) ?></div>
                                <div class="text-[11px] text-slate-400"><?= htmlspecialchars($r['category']) ?></div>
                            </td>

                            <!-- Total Stops -->
                            <td class="px-6 py-4">
                                <button onclick="viewStops(<?= $r['id'] ?>, '<?= htmlspecialchars($r['route_no'], ENT_QUOTES) ?>')" class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-slate-100 hover:bg-blue-100 text-slate-700 hover:text-blue-700 transition text-[11px] font-bold">
                                    <span><?= $r['total_stops'] ?> stops</span>
                                    <span>👁️</span>
                                </button>
                            </td>

                            <!-- Action Buttons -->
                            <td class="px-6 py-4 text-right space-x-1.5 whitespace-nowrap">
                                <button onclick="openEditModal(<?= $r['id'] ?>)" class="px-2.5 py-1 text-xs font-bold text-amber-700 bg-amber-50 hover:bg-amber-100 rounded-lg transition">
                                    ✏️ Edit
                                </button>
                                <button onclick="confirmDelete(<?= $r['id'] ?>, '<?= htmlspecialchars($r['route_no'], ENT_QUOTES) ?>')" class="px-2.5 py-1 text-xs font-bold text-red-700 bg-red-50 hover:bg-red-100 rounded-lg transition">
                                    🗑️ Delete
                                </button>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>

            <!-- Pagination Bar -->
            <?php if ($total_pages > 1): ?>
            <div class="px-6 py-3.5 bg-slate-50 border-t border-slate-100 flex items-center justify-between">
                <div class="text-xs text-slate-500">
                    Showing page <?= $page ?> of <?= $total_pages ?>
                </div>
                <div class="flex items-center gap-1.5">
                    <?php if ($page > 1): ?>
                    <a href="?page=<?= $page - 1 ?>&q=<?= urlencode($search_query) ?>&type=<?= urlencode($filter_type) ?>" class="px-3 py-1 bg-white border border-slate-200 rounded-lg text-xs font-bold text-slate-700 hover:bg-slate-100">Previous</a>
                    <?php endif; ?>

                    <span class="px-3 py-1 bg-blue-600 text-white rounded-lg text-xs font-bold"><?= $page ?></span>

                    <?php if ($page < $total_pages): ?>
                    <a href="?page=<?= $page + 1 ?>&q=<?= urlencode($search_query) ?>&type=<?= urlencode($filter_type) ?>" class="px-3 py-1 bg-white border border-slate-200 rounded-lg text-xs font-bold text-slate-700 hover:bg-slate-100">Next</a>
                    <?php endif; ?>
                </div>
            </div>
            <?php endif; ?>
        </div>

        <?php elseif ($active_tab === 'analytics'): ?>
        <!-- SEARCH ANALYTICS VIEW -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div class="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm">
                <div class="text-[11px] font-bold text-slate-500 uppercase">Total Searches Logged</div>
                <div class="text-2xl font-black text-slate-900 mt-1"><?= number_format($analytics_summary['total_searches']) ?></div>
            </div>
            <div class="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm">
                <div class="text-[11px] font-bold text-slate-500 uppercase">Bus Searches</div>
                <div class="text-2xl font-black text-blue-700 mt-1"><?= number_format($analytics_summary['bus_searches']) ?></div>
            </div>
            <div class="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm">
                <div class="text-[11px] font-bold text-slate-500 uppercase">Metro Searches</div>
                <div class="text-2xl font-black text-emerald-700 mt-1"><?= number_format($analytics_summary['metro_searches']) ?></div>
            </div>
            <div class="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm">
                <div class="text-[11px] font-bold text-slate-500 uppercase">Unique Devices</div>
                <div class="text-2xl font-black text-purple-700 mt-1"><?= number_format($analytics_summary['unique_devices']) ?></div>
            </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
                <div class="px-5 py-3.5 border-b border-slate-100 font-extrabold text-xs text-slate-900 uppercase tracking-wider">Top Searched Bus Stop Corridors</div>
                <div class="divide-y divide-slate-100 text-xs">
                    <?php if (empty($top_bus_corridors)): ?>
                        <div class="p-6 text-center text-slate-400">No bus corridor searches uploaded yet.</div>
                    <?php else: foreach ($top_bus_corridors as $row): ?>
                        <div class="px-5 py-3 flex items-center justify-between">
                            <span class="font-bold text-slate-800"><?= htmlspecialchars($row['from_query']) ?> ➔ <?= htmlspecialchars($row['to_query']) ?></span>
                            <span class="px-2.5 py-0.5 rounded-full bg-blue-50 text-blue-700 font-black"><?= number_format($row['hits']) ?></span>
                        </div>
                    <?php endforeach; endif; ?>
                </div>
            </div>

            <div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
                <div class="px-5 py-3.5 border-b border-slate-100 font-extrabold text-xs text-slate-900 uppercase tracking-wider">Top Searched Bus Numbers</div>
                <div class="divide-y divide-slate-100 text-xs">
                    <?php if (empty($top_bus_numbers)): ?>
                        <div class="p-6 text-center text-slate-400">No bus number searches uploaded yet.</div>
                    <?php else: foreach ($top_bus_numbers as $row): ?>
                        <div class="px-5 py-3 flex items-center justify-between">
                            <span class="px-2 py-0.5 rounded bg-blue-100 text-blue-900 font-black"><?= htmlspecialchars($row['bus_no']) ?></span>
                            <span class="px-2.5 py-0.5 rounded-full bg-purple-50 text-purple-700 font-black"><?= number_format($row['hits']) ?></span>
                        </div>
                    <?php endforeach; endif; ?>
                </div>
            </div>

            <div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
                <div class="px-5 py-3.5 border-b border-slate-100 font-extrabold text-xs text-slate-900 uppercase tracking-wider">Top Searched Metro Routes</div>
                <div class="divide-y divide-slate-100 text-xs">
                    <?php if (empty($top_metro_corridors)): ?>
                        <div class="p-6 text-center text-slate-400">No metro searches uploaded yet.</div>
                    <?php else: foreach ($top_metro_corridors as $row): ?>
                        <div class="px-5 py-3 flex items-center justify-between">
                            <span class="font-bold text-slate-800"><?= htmlspecialchars($row['from_query']) ?> ➔ <?= htmlspecialchars($row['to_query']) ?></span>
                            <span class="px-2.5 py-0.5 rounded-full bg-emerald-50 text-emerald-700 font-black"><?= number_format($row['hits']) ?></span>
                        </div>
                    <?php endforeach; endif; ?>
                </div>
            </div>

            <div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
                <div class="px-5 py-3.5 border-b border-slate-100 font-extrabold text-xs text-slate-900 uppercase tracking-wider">Top Search Locations / IPs</div>
                <div class="divide-y divide-slate-100 text-xs">
                    <?php if (empty($top_search_locations)): ?>
                        <div class="p-6 text-center text-slate-400">No location telemetry recorded yet.</div>
                    <?php else: foreach ($top_search_locations as $row): ?>
                        <div class="px-5 py-3 flex items-center justify-between">
                            <div>
                                <div class="font-bold text-slate-800"><?= htmlspecialchars($row['area']) ?></div>
                                <div class="text-[11px] font-mono text-slate-400"><?= htmlspecialchars($row['ip_address'] ?: '-') ?></div>
                            </div>
                            <span class="px-2.5 py-0.5 rounded-full bg-amber-50 text-amber-700 font-black"><?= number_format($row['hits']) ?></span>
                        </div>
                    <?php endforeach; endif; ?>
                </div>
            </div>
        </div>

        <div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
            <div class="px-5 py-3.5 border-b border-slate-100 font-extrabold text-xs text-slate-900 uppercase tracking-wider">Recent Search Activity Feed</div>
            <div class="overflow-x-auto">
                <table class="w-full text-left text-xs">
                    <thead class="bg-slate-50 text-slate-500 font-bold uppercase border-b border-slate-100">
                        <tr>
                            <th class="px-4 py-3">Mode</th>
                            <th class="px-4 py-3">Query</th>
                            <th class="px-4 py-3">Location / Coordinates</th>
                            <th class="px-4 py-3">IP Address</th>
                            <th class="px-4 py-3">Searched At</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-slate-100">
                        <?php if (empty($recent_searches_log)): ?>
                            <tr><td colspan="5" class="px-4 py-8 text-center text-slate-400">No searches synced yet.</td></tr>
                        <?php else: foreach ($recent_searches_log as $s): ?>
                            <tr>
                                <td class="px-4 py-3 font-bold uppercase text-[11px]"><?= htmlspecialchars($s['search_mode']) ?></td>
                                <td class="px-4 py-3 font-semibold text-slate-800">
                                    <?= $s['search_mode'] === 'bus_no' ? htmlspecialchars($s['bus_no']) : htmlspecialchars($s['from_query'] . ' ➔ ' . $s['to_query']) ?>
                                    <span class="text-[11px] text-slate-400 ml-1">(<?= intval($s['results_count']) ?>)</span>
                                </td>
                                <td class="px-4 py-3 text-slate-600">
                                    <?= htmlspecialchars($s['location_name'] ?: '-') ?>
                                    <?php if (!is_null($s['latitude']) && !is_null($s['longitude'])): ?>
                                        <span class="text-[10px] font-mono text-slate-400 block"><?= number_format((float)$s['latitude'], 4) ?>, <?= number_format((float)$s['longitude'], 4) ?></span>
                                    <?php endif; ?>
                                </td>
                                <td class="px-4 py-3 font-mono text-[11px] text-slate-500"><?= htmlspecialchars($s['ip_address'] ?: '-') ?></td>
                                <td class="px-4 py-3 text-[11px] text-slate-500"><?= htmlspecialchars($s['searched_at'] ?: $s['created_at']) ?></td>
                            </tr>
                        <?php endforeach; endif; ?>
                    </tbody>
                </table>
            </div>
        </div>

        <?php elseif ($active_tab === 'chat'): ?>
        <!-- CHAT IP & LOCATION LOGS VIEW -->
        <div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
            <div class="px-6 py-4 border-b border-slate-100">
                <h2 class="font-extrabold text-slate-900 text-sm">Community Chat Moderation Logs (IP & Location)</h2>
                <p class="text-xs text-slate-500">Private administrator log of sender IP addresses and GPS coordinates.</p>
            </div>
            <div class="overflow-x-auto">
                <table class="w-full text-left text-xs">
                    <thead class="bg-slate-50 text-slate-500 font-bold uppercase border-b border-slate-100">
                        <tr>
                            <th class="px-4 py-3">User</th>
                            <th class="px-4 py-3">Channel</th>
                            <th class="px-4 py-3">Message</th>
                            <th class="px-4 py-3">Location</th>
                            <th class="px-4 py-3">IP Address</th>
                            <th class="px-4 py-3">Time</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-slate-100">
                        <?php if (empty($chat_logs)): ?>
                            <tr><td colspan="6" class="px-4 py-8 text-center text-slate-400">No chat messages found.</td></tr>
                        <?php else: foreach ($chat_logs as $c): ?>
                            <tr>
                                <td class="px-4 py-3 font-bold text-slate-900"><?= htmlspecialchars($c['user_name']) ?></td>
                                <td class="px-4 py-3 text-blue-700 font-semibold">#<?= htmlspecialchars($c['channel']) ?></td>
                                <td class="px-4 py-3 text-slate-700 max-w-md"><?= htmlspecialchars($c['message']) ?></td>
                                <td class="px-4 py-3 text-slate-600">
                                    <?= htmlspecialchars($c['location_name'] ?: '-') ?>
                                    <?php if (!is_null($c['latitude']) && !is_null($c['longitude'])): ?>
                                        <span class="text-[10px] font-mono text-slate-400 block"><?= number_format((float)$c['latitude'], 4) ?>, <?= number_format((float)$c['longitude'], 4) ?></span>
                                    <?php endif; ?>
                                </td>
                                <td class="px-4 py-3 font-mono text-[11px] text-slate-500"><?= htmlspecialchars($c['ip_address'] ?: '-') ?></td>
                                <td class="px-4 py-3 text-[11px] text-slate-500"><?= htmlspecialchars($c['created_at']) ?></td>
                            </tr>
                        <?php endforeach; endif; ?>
                    </tbody>
                </table>
            </div>
        </div>
        <?php endif; ?>

    </main>

    <!-- Footer -->
    <footer class="bg-white border-t border-slate-200 py-4 text-center text-xs text-slate-400">
        CholoKolkata Unified Transit Cloud Engine • Made with Love of Rosogolla 🍮 in Kolkata
    </footer>
</div>

<!-- ======================================================================= -->
<!-- MODAL 1: ADD NEW BUS ROUTE -->
<!-- ======================================================================= -->
<div id="addModal" class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 hidden flex items-center justify-center p-4 overflow-y-auto">
    <div class="bg-white rounded-2xl max-w-2xl w-full shadow-2xl border border-slate-100 overflow-hidden my-8">
        <div class="royal-gradient px-6 py-4 flex items-center justify-between text-white">
            <div class="flex items-center gap-2">
                <span class="text-xl">🚍</span>
                <h3 class="font-extrabold text-base">Add New Bus Route & Stops</h3>
            </div>
            <button onclick="closeModal('addModal')" class="text-white/80 hover:text-white text-lg font-bold">&times;</button>
        </div>

        <form id="addRouteForm" onsubmit="submitAddRoute(event)" class="p-6 space-y-4 max-h-[80vh] overflow-y-auto">
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                    <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Route Number *</label>
                    <input type="text" name="route_no" required placeholder="e.g. AC-54, 215A, S-12/1" 
                        class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 focus:ring-2 focus:ring-blue-500 font-bold uppercase">
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Bus Type</label>
                    <select name="bus_type" class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 bg-white font-medium">
                        <option value="AC Electric Bus">⚡ AC Electric Bus</option>
                        <option value="City Bus (Private/State)" selected>🚌 City Bus (Private/State)</option>
                        <option value="Volvo AC Superfast">❄️ Volvo AC Superfast</option>
                        <option value="Minibus">🚐 Minibus</option>
                        <option value="Electric Mini Bus">⚡ Electric Mini Bus</option>
                    </select>
                </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                    <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Origin Terminal *</label>
                    <input type="text" name="origin" required placeholder="e.g. Howrah Station" 
                        class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 focus:ring-2 focus:ring-blue-500 font-semibold">
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Destination Terminal *</label>
                    <input type="text" name="destination" required placeholder="e.g. Barasat" 
                        class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 focus:ring-2 focus:ring-blue-500 font-semibold">
                </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                    <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Operator / Category</label>
                    <select name="category" class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 bg-white font-medium">
                        <option value="West Bengal Transport Corporation" selected>West Bengal Transport Corporation (WBTC)</option>
                        <option value="Private Bus Syndicate">Private Bus Syndicate</option>
                        <option value="Calcutta State Transport Corp (CSTC)">Calcutta State Transport Corp (CSTC)</option>
                        <option value="South Bengal State Transport Corp (SBSTC)">South Bengal State Transport Corp (SBSTC)</option>
                        <option value="Kolkata Minibus Association">Kolkata Minibus Association</option>
                    </select>
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Operating Hours / Frequency</label>
                    <input type="text" name="timetable" placeholder="e.g. 06:00 AM - 09:30 PM (Every 10-15 mins)" 
                        value="Runs daily 06:00 AM - 09:30 PM (Every 10-15 mins)"
                        class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 focus:ring-2 focus:ring-blue-500 font-medium">
                </div>
            </div>

            <!-- Ordered Stops Sequence Input -->
            <div>
                <div class="flex items-center justify-between mb-1">
                    <label class="block text-xs font-bold text-slate-700 uppercase">Ordered Stops Sequence *</label>
                    <span id="add-stops-count" class="text-[11px] font-bold text-blue-600 bg-blue-50 px-2 py-0.5 rounded-full">0 stops</span>
                </div>
                <textarea name="stops" id="addStopsInput" required rows="5" oninput="updateStopsCount(this.value, 'add-stops-count')"
                    placeholder="Enter stops in order, separated by commas (,) or one per line:&#10;Howrah Station, Barabazar, Girish Park, Maniktala, Ultadanga, Airport Gate 1, Madhyamgram, Barasat" 
                    class="w-full px-3 py-2.5 text-xs rounded-xl border border-slate-200 focus:ring-2 focus:ring-blue-500 font-medium leading-relaxed"></textarea>
                <p class="text-[11px] text-slate-400 mt-1">Stops will be indexed sequentially (Stop 1, Stop 2...). Commuters can search from any intermediate stop to any other stop on this route.</p>
            </div>

            <div class="pt-4 border-t border-slate-100 flex items-center justify-end gap-2">
                <button type="button" onclick="closeModal('addModal')" class="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl transition">Cancel</button>
                <button type="submit" id="addSubmitBtn" class="px-5 py-2.5 royal-gradient text-white text-xs font-extrabold rounded-xl shadow-lg shadow-blue-500/20 hover:opacity-95 transition">
                    Publish Route to Live App
                </button>
            </div>
        </form>
    </div>
</div>

<!-- ======================================================================= -->
<!-- MODAL 2: EDIT BUS ROUTE -->
<!-- ======================================================================= -->
<div id="editModal" class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 hidden flex items-center justify-center p-4 overflow-y-auto">
    <div class="bg-white rounded-2xl max-w-2xl w-full shadow-2xl border border-slate-100 overflow-hidden my-8">
        <div class="bg-amber-500 px-6 py-4 flex items-center justify-between text-white">
            <div class="flex items-center gap-2">
                <span class="text-xl">✏️</span>
                <h3 class="font-extrabold text-base" id="editModalTitle">Edit Bus Route</h3>
            </div>
            <button onclick="closeModal('editModal')" class="text-white/80 hover:text-white text-lg font-bold">&times;</button>
        </div>

        <form id="editRouteForm" onsubmit="submitEditRoute(event)" class="p-6 space-y-4 max-h-[80vh] overflow-y-auto">
            <input type="hidden" name="route_id" id="edit_route_id">

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                    <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Route Number *</label>
                    <input type="text" name="route_no" id="edit_route_no" required 
                        class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 focus:ring-2 focus:ring-amber-500 font-bold uppercase">
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Bus Type</label>
                    <select name="bus_type" id="edit_bus_type" class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 bg-white font-medium">
                        <option value="AC Electric Bus">⚡ AC Electric Bus</option>
                        <option value="City Bus (Private/State)">🚌 City Bus (Private/State)</option>
                        <option value="Volvo AC Superfast">❄️ Volvo AC Superfast</option>
                        <option value="Minibus">🚐 Minibus</option>
                        <option value="Electric Mini Bus">⚡ Electric Mini Bus</option>
                    </select>
                </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                    <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Origin Terminal *</label>
                    <input type="text" name="origin" id="edit_origin" required 
                        class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 focus:ring-2 focus:ring-amber-500 font-semibold">
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Destination Terminal *</label>
                    <input type="text" name="destination" id="edit_destination" required 
                        class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 focus:ring-2 focus:ring-amber-500 font-semibold">
                </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                    <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Operator / Category</label>
                    <select name="category" id="edit_category" class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 bg-white font-medium">
                        <option value="West Bengal Transport Corporation">West Bengal Transport Corporation (WBTC)</option>
                        <option value="Private Bus Syndicate">Private Bus Syndicate</option>
                        <option value="Calcutta State Transport Corp (CSTC)">Calcutta State Transport Corp (CSTC)</option>
                        <option value="South Bengal State Transport Corp (SBSTC)">South Bengal State Transport Corp (SBSTC)</option>
                        <option value="Kolkata Minibus Association">Kolkata Minibus Association</option>
                    </select>
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Operating Hours / Frequency</label>
                    <input type="text" name="timetable" id="edit_timetable" 
                        class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 focus:ring-2 focus:ring-amber-500 font-medium">
                </div>
            </div>

            <div>
                <div class="flex items-center justify-between mb-1">
                    <label class="block text-xs font-bold text-slate-700 uppercase">Ordered Stops Sequence *</label>
                    <span id="edit-stops-count" class="text-[11px] font-bold text-amber-600 bg-amber-50 px-2 py-0.5 rounded-full">0 stops</span>
                </div>
                <textarea name="stops" id="editStopsInput" required rows="5" oninput="updateStopsCount(this.value, 'edit-stops-count')"
                    class="w-full px-3 py-2.5 text-xs rounded-xl border border-slate-200 focus:ring-2 focus:ring-amber-500 font-medium leading-relaxed"></textarea>
                <p class="text-[11px] text-slate-400 mt-1">Separate stops with commas or newlines. Order is strictly preserved.</p>
            </div>

            <div class="pt-4 border-t border-slate-100 flex items-center justify-end gap-2">
                <button type="button" onclick="closeModal('editModal')" class="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl transition">Cancel</button>
                <button type="submit" id="editSubmitBtn" class="px-5 py-2.5 bg-amber-600 text-white text-xs font-extrabold rounded-xl shadow-lg shadow-amber-500/20 hover:bg-amber-700 transition">
                    Save Changes & Update Stops
                </button>
            </div>
        </form>
    </div>
</div>

<!-- ======================================================================= -->
<!-- MODAL 3: VIEW STOPS TIMELINE -->
<!-- ======================================================================= -->
<div id="viewModal" class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 hidden flex items-center justify-center p-4">
    <div class="bg-white rounded-2xl max-w-lg w-full shadow-2xl border border-slate-100 overflow-hidden">
        <div class="royal-gradient px-6 py-4 flex items-center justify-between text-white">
            <div>
                <div class="text-xs text-blue-200 font-bold uppercase tracking-wider">Route Timeline</div>
                <h3 class="font-extrabold text-base" id="viewModalTitle">Bus Stops</h3>
            </div>
            <button onclick="closeModal('viewModal')" class="text-white/80 hover:text-white text-lg font-bold">&times;</button>
        </div>

        <div class="p-6 max-h-[70vh] overflow-y-auto">
            <div id="viewStopsTimeline" class="space-y-3 relative before:absolute before:inset-0 before:left-3 before:w-0.5 before:bg-blue-200 before:z-0">
                <!-- Injected via JavaScript -->
            </div>
        </div>

        <div class="px-6 py-3 bg-slate-50 border-t border-slate-100 text-right">
            <button onclick="closeModal('viewModal')" class="px-4 py-1.5 text-xs font-bold text-slate-600 bg-white border border-slate-200 rounded-xl hover:bg-slate-100 transition">Close</button>
        </div>
    </div>
</div>

<!-- Toast Feedback Container -->
<div id="toast" class="fixed bottom-6 right-6 z-50 transform transition-all duration-300 translate-y-24 opacity-0 pointer-events-none">
    <div class="px-4 py-3 bg-slate-900 text-white text-xs font-bold rounded-2xl shadow-2xl flex items-center gap-2 border border-slate-700">
        <span id="toastIcon">✓</span>
        <span id="toastMsg">Operation successful!</span>
    </div>
</div>

<!-- ======================================================================= -->
<!-- JAVASCRIPT LOGIC -->
<!-- ======================================================================= -->
<script>
function showToast(msg, isError = false) {
    const toast = document.getElementById('toast');
    const toastMsg = document.getElementById('toastMsg');
    const toastIcon = document.getElementById('toastIcon');

    toastMsg.textContent = msg;
    toastIcon.textContent = isError ? '⚠️' : '✓';
    toast.className = `fixed bottom-6 right-6 z-50 transform transition-all duration-300 translate-y-0 opacity-100 ${isError ? 'bg-red-900 text-white' : 'bg-slate-900 text-white'}`;

    setTimeout(() => {
        toast.className = 'fixed bottom-6 right-6 z-50 transform transition-all duration-300 translate-y-24 opacity-0 pointer-events-none';
    }, 3500);
}

function openAddModal() {
    document.getElementById('addRouteForm').reset();
    document.getElementById('add-stops-count').textContent = '0 stops';
    document.getElementById('addModal').classList.remove('hidden');
}

function closeModal(id) {
    document.getElementById(id).classList.add('hidden');
}

function updateStopsCount(text, elementId) {
    if (!text) {
        document.getElementById(elementId).textContent = '0 stops';
        return;
    }
    const stops = text.split(/[,\n]+/).map(s => s.trim()).filter(Boolean);
    document.getElementById(elementId).textContent = `${stops.length} stops detected`;
}

// 1. Submit Add Route
async function submitAddRoute(e) {
    e.preventDefault();
    const btn = document.getElementById('addSubmitBtn');
    btn.disabled = true;
    btn.textContent = 'Publishing to MySQL...';

    const form = e.target;
    const formData = new FormData(form);

    try {
        const res = await fetch('/admin?action=add_route', {
            method: 'POST',
            body: formData
        });
        const data = await res.json();
        if (data.success) {
            showToast(data.message);
            closeModal('addModal');
            setTimeout(() => window.location.reload(), 1000);
        } else {
            showToast(data.error || 'Failed to add route', true);
        }
    } catch (err) {
        showToast('Network error while saving route.', true);
    } finally {
        btn.disabled = false;
        btn.textContent = 'Publish Route to Live App';
    }
}

// 2. Open Edit Modal & Populate
async function openEditModal(routeId) {
    try {
        const res = await fetch(`/admin?action=get_route&id=${routeId}`);
        const data = await res.json();
        if (!data.success) {
            showToast(data.error || 'Could not fetch route', true);
            return;
        }

        const r = data.route;
        const stops = data.stops || [];

        document.getElementById('edit_route_id').value = r.id;
        document.getElementById('edit_route_no').value = r.route_no;
        document.getElementById('edit_origin').value = r.origin;
        document.getElementById('edit_destination').value = r.destination;
        document.getElementById('edit_bus_type').value = r.bus_type;
        document.getElementById('edit_category').value = r.category;
        document.getElementById('edit_timetable').value = r.timetable || '';
        document.getElementById('editModalTitle').textContent = `Edit Route ${r.route_no}`;

        const stopsText = stops.map(s => s.stop_name).join(', ');
        document.getElementById('editStopsInput').value = stopsText;
        updateStopsCount(stopsText, 'edit-stops-count');

        document.getElementById('editModal').classList.remove('hidden');
    } catch (err) {
        showToast('Error loading route details', true);
    }
}

// 3. Submit Edit Route
async function submitEditRoute(e) {
    e.preventDefault();
    const btn = document.getElementById('editSubmitBtn');
    btn.disabled = true;
    btn.textContent = 'Updating...';

    const form = e.target;
    const formData = new FormData(form);

    try {
        const res = await fetch('/admin?action=edit_route', {
            method: 'POST',
            body: formData
        });
        const data = await res.json();
        if (data.success) {
            showToast(data.message);
            closeModal('editModal');
            setTimeout(() => window.location.reload(), 1000);
        } else {
            showToast(data.error || 'Failed to update route', true);
        }
    } catch (err) {
        showToast('Network error updating route', true);
    } finally {
        btn.disabled = false;
        btn.textContent = 'Save Changes & Update Stops';
    }
}

// 4. View Stops Sequence Timeline
async function viewStops(routeId, routeNo) {
    const container = document.getElementById('viewStopsTimeline');
    container.innerHTML = '<div class="text-xs text-slate-400 py-4 text-center">Loading stops...</div>';
    document.getElementById('viewModalTitle').textContent = `Route ${routeNo} Stop Timeline`;
    document.getElementById('viewModal').classList.remove('hidden');

    try {
        const res = await fetch(`/admin?action=get_route&id=${routeId}`);
        const data = await res.json();
        if (!data.success || !data.stops || data.stops.length === 0) {
            container.innerHTML = '<div class="text-xs text-slate-400 py-4 text-center">No stops recorded for this route.</div>';
            return;
        }

        let html = '';
        data.stops.forEach((s, idx) => {
            const isFirst = idx === 0;
            const isLast = idx === data.stops.length - 1;
            const badgeColor = isFirst ? 'bg-emerald-600 text-white' : (isLast ? 'bg-red-600 text-white' : 'bg-blue-600 text-white');
            const label = isFirst ? 'Origin Terminal' : (isLast ? 'Destination Terminal' : `Stop #${s.stop_order}`);

            html += `
            <div class="relative z-10 flex items-start gap-3">
                <div class="w-6 h-6 rounded-full ${badgeColor} flex items-center justify-center text-[10px] font-black shrink-0 shadow-sm mt-0.5">
                    ${s.stop_order}
                </div>
                <div>
                    <div class="font-extrabold text-xs text-slate-900">${s.stop_name}</div>
                    <div class="text-[10px] text-slate-400 font-semibold uppercase">${label}</div>
                </div>
            </div>`;
        });
        container.innerHTML = html;
    } catch (err) {
        container.innerHTML = '<div class="text-xs text-red-500 py-4 text-center">Failed to load stops timeline.</div>';
    }
}

// 5. Confirm & Delete Route
async function confirmDelete(routeId, routeNo) {
    if (!confirm(`Are you sure you want to permanently delete route "${routeNo}"?\nAll associated stops will be removed from this route.`)) {
        return;
    }

    const formData = new FormData();
    formData.append('route_id', routeId);

    try {
        const res = await fetch('/admin?action=delete_route', {
            method: 'POST',
            body: formData
        });
        const data = await res.json();
        if (data.success) {
            showToast(`Route ${routeNo} deleted.`);
            setTimeout(() => window.location.reload(), 1000);
        } else {
            showToast(data.error || 'Failed to delete route', true);
        }
    } catch (err) {
        showToast('Network error while deleting route', true);
    }
}

// 6. Bump OTA Version
async function triggerOtaBump() {
    const btn = document.getElementById('ota-btn-label');
    btn.textContent = 'Broadcasting...';
    try {
        const res = await fetch('/admin?action=bump_sync', { method: 'POST' });
        const data = await res.json();
        if (data.success) {
            showToast(data.message);
        } else {
            showToast('OTA broadcast failed', true);
        }
    } catch (err) {
        showToast('Error publishing OTA update', true);
    } finally {
        btn.textContent = 'Publish OTA Sync';
    }
}
</script>
</body>
</html>
<?php endif; ?>

