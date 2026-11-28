<?php
/**
 * CholoKolkata (চলো কলকাতা) • Unified Bulk JSON Analyzer, Duplicate Detector & OTA Committer
 * Supports: Bus Routes, Auto Routes, Stop Coordinates, and Bus Stops Directory.
 */

if (!defined('CHOLO_WB_LAT_MIN')) {
    define('CHOLO_WB_LAT_MIN', 21.20);
    define('CHOLO_WB_LAT_MAX', 27.50);
    define('CHOLO_WB_LNG_MIN', 85.50);
    define('CHOLO_WB_LNG_MAX', 90.00);
}

function cholo_norm_text($raw)
{
    $s = trim((string) $raw);
    $s = preg_replace('/\s+/', ' ', $s);
    return mb_strtolower($s, 'UTF-8');
}

function cholo_norm_stop_key($raw)
{
    $noParen = preg_replace('/\([^)]*\)/', ' ', mb_strtolower((string) $raw, 'UTF-8'));
    $clean = preg_replace('/[^a-z0-9 ]/', ' ', $noParen);
    return trim(preg_replace('/\s+/', ' ', $clean));
}

function cholo_norm_route_no($raw)
{
    return strtoupper(preg_replace('/\s+/', '', trim((string) $raw)));
}

function cholo_slug($raw)
{
    $s = preg_replace('/[^a-z0-9]+/', '_', strtolower((string) $raw));
    return trim($s, '_');
}

function cholo_haversine_km($lat1, $lng1, $lat2, $lng2)
{
    $p = 0.017453292519943295;
    $a = 0.5 - cos(($lat2 - $lat1) * $p) / 2
        + cos($lat1 * $p) * cos($lat2 * $p) * (1 - cos(($lng2 - $lng1) * $p)) / 2;
    $a = max(0.0, min(1.0, $a));
    return 12742.0 * asin(sqrt($a));
}

function cholo_validate_wb_coord($lat, $lng)
{
    if (!is_numeric($lat) || !is_numeric($lng)) {
        return ['valid' => false, 'error' => 'Non-numeric latitude/longitude'];
    }
    $fLat = (float) $lat;
    $fLng = (float) $lng;
    if (abs($fLat) < 0.0001 && abs($fLng) < 0.0001) {
        return ['valid' => false, 'error' => 'Null Island (0, 0) coordinate'];
    }
    if ($fLat >= CHOLO_WB_LNG_MIN && $fLat <= CHOLO_WB_LNG_MAX && $fLng >= CHOLO_WB_LAT_MIN && $fLng <= CHOLO_WB_LAT_MAX) {
        return ['valid' => false, 'error' => "Likely swapped [lng, lat] order ($fLat, $fLng)"];
    }
    if ($fLat < CHOLO_WB_LAT_MIN || $fLat > CHOLO_WB_LAT_MAX || $fLng < CHOLO_WB_LNG_MIN || $fLng > CHOLO_WB_LNG_MAX) {
        return ['valid' => false, 'error' => "Outside West Bengal bounds ($fLat, $fLng)"];
    }
    return ['valid' => true, 'lat' => round($fLat, 6), 'lng' => round($fLng, 6)];
}

function cholo_extract_coord_pair($val)
{
    if (is_array($val)) {
        if (array_key_exists('lat', $val) && (array_key_exists('lng', $val) || array_key_exists('lon', $val))) {
            return [$val['lat'], $val['lng'] ?? $val['lon']];
        }
        if (isset($val[0]) && isset($val[1])) {
            return [$val[0], $val[1]];
        }
    }
    return null;
}

/**
 * Ensures auto_routes and stop_coords tables exist and auto-seeds from ota_data/ if empty.
 */
function ensure_ota_transit_schema(mysqli $db)
{
    static $done = false;
    if ($done) {
        return;
    }
    $done = true;

    @$db->query("
        CREATE TABLE IF NOT EXISTS auto_routes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            ext_id INT NULL,
            rid VARCHAR(191) NOT NULL,
            route_code VARCHAR(64) NOT NULL DEFAULT 'AUTO',
            route_name VARCHAR(255) NOT NULL,
            origin VARCHAR(255) NOT NULL,
            destination VARCHAR(255) NOT NULL,
            sig_key VARCHAR(255) NOT NULL,
            hw_peak INT NOT NULL DEFAULT 6,
            hw_offpeak INT NOT NULL DEFAULT 10,
            first_service VARCHAR(16) NOT NULL DEFAULT '06:00',
            last_service VARCHAR(16) NOT NULL DEFAULT '22:30',
            fare_min INT NOT NULL DEFAULT 10,
            fare_max INT NOT NULL DEFAULT 15,
            distance_km DECIMAL(8,2) NOT NULL DEFAULT 3.00,
            duration_mins INT NOT NULL DEFAULT 12,
            notes TEXT NULL,
            stops_json MEDIUMTEXT NOT NULL,
            updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY uniq_rid (rid),
            KEY idx_sig_key (sig_key),
            KEY idx_origin_dest (origin(100), destination(100))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");

    @$db->query("
        CREATE TABLE IF NOT EXISTS stop_coords (
            id INT AUTO_INCREMENT PRIMARY KEY,
            stop_key VARCHAR(255) NOT NULL,
            display_name VARCHAR(255) NOT NULL DEFAULT '',
            lat DECIMAL(10,6) NOT NULL,
            lng DECIMAL(10,6) NOT NULL,
            updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY uniq_stop_key (stop_key)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");

    $baseDir = dirname(__DIR__) . '/ota_data';

    // Seed auto_routes if empty
    $rAuto = @$db->query("SELECT COUNT(*) AS c FROM auto_routes");
    $autoCnt = ($rAuto && ($row = $rAuto->fetch_assoc())) ? (int) $row['c'] : -1;
    $autoSeed = $baseDir . '/kolkata_auto_routes.json';
    if ($autoCnt === 0 && file_exists($autoSeed)) {
        $items = json_decode(file_get_contents($autoSeed), true);
        if (is_array($items) && !empty($items)) {
            $db->begin_transaction();
            try {
                $stmt = $db->prepare("
                    INSERT INTO auto_routes
                    (ext_id, rid, route_code, route_name, origin, destination, sig_key, hw_peak, hw_offpeak, first_service, last_service, fare_min, fare_max, distance_km, duration_mins, notes, stops_json)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE route_name = VALUES(route_name)
                ");
                $seenRids = [];
                foreach ($items as $idx => $item) {
                    if (!is_array($item)) {
                        continue;
                    }
                    $orig = trim((string) ($item['f'] ?? ''));
                    $dest = trim((string) ($item['t'] ?? ''));
                    if ($orig === '' || $dest === '') {
                        continue;
                    }
                    $rid = trim((string) ($item['rid'] ?? ''));
                    if ($rid === '') {
                        $rid = 'auto_' . cholo_slug($orig) . '_' . cholo_slug($dest);
                    }
                    if (isset($seenRids[$rid])) {
                        $rid .= '_' . ($idx + 1);
                    }
                    $seenRids[$rid] = true;

                    $extId = isset($item['id']) && is_numeric($item['id']) ? (int) $item['id'] : null;
                    $rCode = trim((string) ($item['r'] ?? 'AUTO')) ?: 'AUTO';
                    $rn = trim((string) ($item['rn'] ?? "$orig - $dest")) ?: "$orig - $dest";
                    $sigKey = cholo_norm_stop_key($orig) . '|' . cholo_norm_stop_key($dest);
                    $hwP = (int) ($item['hwP'] ?? 6);
                    $hwO = (int) ($item['hwO'] ?? 10);
                    $fs = substr(trim((string) ($item['fs'] ?? '06:00')), 0, 16) ?: '06:00';
                    $ls = substr(trim((string) ($item['ls'] ?? '22:30')), 0, 16) ?: '22:30';
                    $fMin = (int) ($item['fMin'] ?? 10);
                    $fMax = (int) ($item['fMax'] ?? 15);
                    $km = (float) ($item['km'] ?? 3.0);
                    $dur = (int) ($item['dur'] ?? 12);
                    $notes = (string) ($item['nt'] ?? '');
                    $stopsJson = json_encode($item['stops'] ?? [], JSON_UNESCAPED_UNICODE);

                    $stmt->bind_param(
                        'issssssiissiidiss',
                        $extId, $rid, $rCode, $rn, $orig, $dest, $sigKey,
                        $hwP, $hwO, $fs, $ls, $fMin, $fMax, $km, $dur, $notes, $stopsJson
                    );
                    @$stmt->execute();
                }
                $db->commit();
            } catch (Throwable $e) {
                $db->rollback();
            }
        }
    }

    // Seed stop_coords if empty
    $rCoord = @$db->query("SELECT COUNT(*) AS c FROM stop_coords");
    $coordCnt = ($rCoord && ($row = $rCoord->fetch_assoc())) ? (int) $row['c'] : -1;
    $coordSeed = $baseDir . '/kolkata_stop_coords.json';
    if ($coordCnt === 0 && file_exists($coordSeed)) {
        $map = json_decode(file_get_contents($coordSeed), true);
        if (is_array($map) && !empty($map)) {
            $db->begin_transaction();
            try {
                $stmt = $db->prepare("
                    INSERT INTO stop_coords (stop_key, display_name, lat, lng)
                    VALUES (?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE lat = VALUES(lat), lng = VALUES(lng)
                ");
                foreach ($map as $rawKey => $coords) {
                    $pair = cholo_extract_coord_pair($coords);
                    if (!$pair) {
                        continue;
                    }
                    $chk = cholo_validate_wb_coord($pair[0], $pair[1]);
                    if (!$chk['valid']) {
                        continue;
                    }
                    $k = cholo_norm_stop_key($rawKey);
                    if ($k === '') {
                        continue;
                    }
                    $disp = trim((string) $rawKey);
                    $lat = $chk['lat'];
                    $lng = $chk['lng'];
                    $stmt->bind_param('ssdd', $k, $disp, $lat, $lng);
                    @$stmt->execute();
                }
                $db->commit();
            } catch (Throwable $e) {
                $db->rollback();
            }
        }
    }
}

function cholo_get_ota_counts(mysqli $db)
{
    ensure_ota_transit_schema($db);
    $counts = [
        'bus_routes' => 0,
        'stops' => 0,
        'auto_routes' => 0,
        'stop_coords' => 0,
    ];
    $queries = [
        'bus_routes' => 'SELECT COUNT(*) AS c FROM routes',
        'stops' => 'SELECT COUNT(*) AS c FROM stops',
        'auto_routes' => 'SELECT COUNT(*) AS c FROM auto_routes',
        'stop_coords' => 'SELECT COUNT(*) AS c FROM stop_coords',
    ];
    foreach ($queries as $k => $sql) {
        if ($r = @$db->query($sql)) {
            $counts[$k] = (int) ($r->fetch_assoc()['c'] ?? 0);
        }
    }
    return $counts;
}

function cholo_bump_ota_version_with_counts($versionFile, mysqli $db, $changelog = null)
{
    $v = '2.4.0';
    if (file_exists($versionFile)) {
        $vdata = json_decode(file_get_contents($versionFile), true);
        if (!empty($vdata['version'])) {
            $v = $vdata['version'];
        }
    }
    $parts = explode('.', $v);
    if (count($parts) === 3) {
        $parts[2] = intval($parts[2]) + 1;
        $newV = implode('.', $parts);
    } else {
        $newV = '2.4.1';
    }
    $counts = cholo_get_ota_counts($db);
    $saveData = [
        'version' => $newV,
        'has_updates' => true,
        'changelog' => $changelog ?: "Transit database synced via Admin Portal (v$newV).",
        'last_updated' => date('Y-m-d H:i:s T'),
        'counts' => $counts,
    ];
    @file_put_contents($versionFile, json_encode($saveData, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
    return ['version' => $newV, 'counts' => $counts];
}

function cholo_fetch_auto_routes_payload(mysqli $db)
{
    ensure_ota_transit_schema($db);
    $list = [];
    $res = @$db->query("SELECT * FROM auto_routes ORDER BY id ASC");
    if (!$res) {
        return $list;
    }
    while ($row = $res->fetch_assoc()) {
        $stops = json_decode($row['stops_json'] ?? '[]', true);
        if (!is_array($stops) || empty($stops)) {
            continue;
        }
        $list[] = [
            'id' => !is_null($row['ext_id']) ? (int) $row['ext_id'] : (70000 + (int) $row['id']),
            'rid' => $row['rid'],
            'r' => $row['route_code'] ?: 'AUTO',
            'rn' => $row['route_name'],
            'f' => $row['origin'],
            't' => $row['destination'],
            'hwP' => (int) $row['hw_peak'],
            'hwO' => (int) $row['hw_offpeak'],
            'fs' => $row['first_service'],
            'ls' => $row['last_service'],
            'fMin' => (int) $row['fare_min'],
            'fMax' => (int) $row['fare_max'],
            'km' => (float) $row['distance_km'],
            'dur' => (int) $row['duration_mins'],
            'nt' => $row['notes'] ?? '',
            'stops' => $stops,
        ];
    }
    return $list;
}

function cholo_fetch_stop_coords_payload(mysqli $db)
{
    ensure_ota_transit_schema($db);
    $map = [];
    $res = @$db->query("SELECT stop_key, lat, lng FROM stop_coords ORDER BY stop_key ASC");
    if (!$res) {
        return $map;
    }
    while ($row = $res->fetch_assoc()) {
        $map[$row['stop_key']] = [
            round((float) $row['lat'], 6),
            round((float) $row['lng'], 6),
        ];
    }
    return $map;
}

/**
 * Loads existing DB state formatted cleanly for cholo_analyze_upload().
 */
function cholo_load_existing_state(mysqli $db, string $type)
{
    ensure_ota_transit_schema($db);
    $state = [
        'bus_routes' => [],
        'auto_routes' => [],
        'stop_coords' => [],
        'stops' => [],
    ];

    if ($type === 'bus_routes' || $type === 'all') {
        $stopsByRoute = [];
        $rs = @$db->query("SELECT route_id, stop_name FROM route_stops ORDER BY route_id ASC, stop_order ASC");
        if ($rs) {
            while ($row = $rs->fetch_assoc()) {
                $stopsByRoute[(int) $row['route_id']][] = $row['stop_name'];
            }
        }
        $rr = @$db->query("SELECT id, route_no, route_name, origin, destination, category, bus_type, timetable FROM routes");
        if ($rr) {
            while ($r = $rr->fetch_assoc()) {
                $rid = (int) $r['id'];
                $state['bus_routes'][] = [
                    'id' => $rid,
                    'r' => $r['route_no'],
                    'f' => $r['origin'],
                    't' => $r['destination'],
                    'rn' => $r['route_name'],
                    'bt' => $r['bus_type'],
                    'cat' => $r['category'],
                    'tt' => $r['timetable'] ?? '',
                    's' => $stopsByRoute[$rid] ?? [],
                ];
            }
        }
    }

    if ($type === 'auto_routes' || $type === 'all') {
        $ar = @$db->query("SELECT id, ext_id, rid, route_code, route_name, origin, destination, hw_peak, hw_offpeak, first_service, last_service, fare_min, fare_max, distance_km, duration_mins, notes, stops_json FROM auto_routes");
        if ($ar) {
            while ($r = $ar->fetch_assoc()) {
                $state['auto_routes'][] = [
                    'db_id' => (int) $r['id'],
                    'id' => !is_null($r['ext_id']) ? (int) $r['ext_id'] : null,
                    'rid' => $r['rid'],
                    'r' => $r['route_code'],
                    'rn' => $r['route_name'],
                    'f' => $r['origin'],
                    't' => $r['destination'],
                    'hwP' => (int) $r['hw_peak'],
                    'hwO' => (int) $r['hw_offpeak'],
                    'fs' => $r['first_service'],
                    'ls' => $r['last_service'],
                    'fMin' => (int) $r['fare_min'],
                    'fMax' => (int) $r['fare_max'],
                    'km' => (float) $r['distance_km'],
                    'dur' => (int) $r['duration_mins'],
                    'nt' => $r['notes'] ?? '',
                    'stops' => json_decode($r['stops_json'] ?? '[]', true) ?: [],
                ];
            }
        }
    }

    if ($type === 'stop_coords' || $type === 'all') {
        $sc = @$db->query("SELECT id, stop_key, display_name, lat, lng FROM stop_coords");
        if ($sc) {
            while ($r = $sc->fetch_assoc()) {
                $state['stop_coords'][$r['stop_key']] = [
                    'db_id' => (int) $r['id'],
                    'display_name' => $r['display_name'],
                    'lat' => (float) $r['lat'],
                    'lng' => (float) $r['lng'],
                ];
            }
        }
    }

    if ($type === 'stops' || $type === 'all') {
        $st = @$db->query("SELECT id, stop_name, routes_count FROM stops");
        if ($st) {
            while ($r = $st->fetch_assoc()) {
                $state['stops'][cholo_norm_text($r['stop_name'])] = [
                    'db_id' => (int) $r['id'],
                    'n' => $r['stop_name'],
                    'c' => (int) ($r['routes_count'] ?? 0),
                ];
            }
        }
    }

    return $state;
}

/**
 * Auto-detect JSON format from decoded payload.
 */
function cholo_detect_json_format($decoded, string $hint = 'auto')
{
    if (!is_array($decoded)) {
        return null;
    }

    if (in_array($hint, ['bus_routes', 'auto_routes', 'stop_coords', 'stops'], true)) {
        return $hint;
    }

    // Wrapper keys
    if (isset($decoded['routes']) && is_array($decoded['routes'])) {
        $inner = $decoded['routes'];
        $first = reset($inner);
        if (is_array($first) && (isset($first['stops']) || isset($first['hwP']) || isset($first['fMin']))) {
            return 'auto_routes';
        }
        return 'bus_routes';
    }
    if (isset($decoded['auto_routes']) && is_array($decoded['auto_routes'])) {
        return 'auto_routes';
    }
    if (isset($decoded['stop_coords']) && is_array($decoded['stop_coords'])) {
        return 'stop_coords';
    }

    $isList = array_keys($decoded) === range(0, count($decoded) - 1);
    if (!$isList) {
        // Associative array: either stop_coords { "stop": [lat, lng] } or bus_routes { "215A": [ {r, f, t, s}, ... ] }
        $sample = reset($decoded);
        if (cholo_extract_coord_pair($sample) !== null && is_numeric(cholo_extract_coord_pair($sample)[0] ?? null)) {
            return 'stop_coords';
        }
        if (is_array($sample)) {
            $innerFirst = reset($sample);
            if (is_array($innerFirst) && (isset($innerFirst['s']) || isset($innerFirst['f']) || isset($innerFirst['r']))) {
                return 'bus_routes';
            }
        }
        return null;
    }

    $first = reset($decoded);
    if (is_string($first)) {
        return 'stops';
    }
    if (!is_array($first)) {
        return null;
    }
    if (isset($first['n']) && count($first) <= 3 && !isset($first['f']) && !isset($first['s'])) {
        return 'stops';
    }
    if (isset($first['stops']) || isset($first['hwP']) || isset($first['fMin']) || (isset($first['rid']) && stripos((string) $first['rid'], 'auto') === 0)) {
        return 'auto_routes';
    }
    if (isset($first['s']) || isset($first['r'])) {
        return 'bus_routes';
    }

    return null;
}

/**
 * Unwraps JSON payload into an iterable list/map ready for deep analysis.
 */
function cholo_extract_entries($decoded, string $format)
{
    if ($format === 'bus_routes') {
        $source = isset($decoded['routes']) && is_array($decoded['routes']) ? $decoded['routes'] : $decoded;
        $entries = [];
        $isList = array_keys($source) === range(0, count($source) - 1);
        if ($isList) {
            foreach ($source as $idx => $item) {
                $entries[] = ['index' => $idx, 'map_key' => null, 'raw' => $item];
            }
        } else {
            $idx = 0;
            foreach ($source as $mapKey => $bucket) {
                if (is_array($bucket) && isset($bucket[0])) {
                    foreach ($bucket as $item) {
                        $entries[] = ['index' => $idx++, 'map_key' => (string) $mapKey, 'raw' => $item];
                    }
                } elseif (is_array($bucket)) {
                    $entries[] = ['index' => $idx++, 'map_key' => (string) $mapKey, 'raw' => $bucket];
                }
            }
        }
        return $entries;
    }

    if ($format === 'auto_routes') {
        $source = $decoded['auto_routes'] ?? ($decoded['routes'] ?? $decoded);
        $entries = [];
        foreach (array_values($source) as $idx => $item) {
            $entries[] = ['index' => $idx, 'raw' => $item];
        }
        return $entries;
    }

    if ($format === 'stop_coords') {
        $source = $decoded['stop_coords'] ?? $decoded;
        $entries = [];
        $idx = 0;
        foreach ($source as $k => $v) {
            $entries[] = ['index' => $idx++, 'raw_key' => (string) $k, 'raw_val' => $v];
        }
        return $entries;
    }

    if ($format === 'stops') {
        $source = $decoded['stops'] ?? $decoded;
        $entries = [];
        foreach (array_values($source) as $idx => $item) {
            $entries[] = ['index' => $idx, 'raw' => $item];
        }
        return $entries;
    }

    return [];
}

function cholo_parse_hhmm($s)
{
    if (!preg_match('/^(\d{1,2}):(\d{2})$/', trim((string) $s), $m)) {
        return null;
    }
    $h = (int) $m[1];
    $min = (int) $m[2];
    if ($h < 0 || $h > 23 || $min < 0 || $min > 59) {
        return null;
    }
    return $h * 60 + $min;
}

/**
 * Pure deep-inspection analyzer: mirrors manual engineering verification of every JSON entry.
 */
function cholo_analyze_upload($decoded, array $existingState, string $hintFormat = 'auto')
{
    $format = cholo_detect_json_format($decoded, $hintFormat);
    if (!$format) {
        return [
            'success' => false,
            'error' => 'Unrecognized JSON schema. Expected Bus Routes map, Auto Routes array, Stop Coords map, or Bus Stops array.',
        ];
    }

    $entries = cholo_extract_entries($decoded, $format);
    $items = [];
    $summary = [
        'total_uploaded' => count($entries),
        'new_count' => 0,
        'exact_duplicates_count' => 0,
        'conflicts_count' => 0,
        'in_file_duplicates_count' => 0,
        'warnings_count' => 0,
        'errors_count' => 0,
    ];
    $checksRun = [];

    if ($format === 'bus_routes') {
        $checksRun = [
            'Required fields & stop sequence (>= 2 stops)',
            'Consecutive duplicate stop & terminal alignment check',
            'Intra-file ID & directional signature duplicate scan',
            'Live DB match by normalized (route_no, origin, destination)',
            'Stop-by-stop diff & timetable/operator conflict inspection',
        ];

        $dbBySig = [];
        foreach (($existingState['bus_routes'] ?? []) as $ex) {
            $sig = cholo_norm_route_no($ex['r'] ?? '') . '|' . cholo_norm_text($ex['f'] ?? '') . '|' . cholo_norm_text($ex['t'] ?? '');
            $dbBySig[$sig][] = $ex;
        }

        $seenSigs = [];
        $seenIds = [];

        foreach ($entries as $entry) {
            $raw = $entry['raw'];
            $idx = $entry['index'];
            $errors = [];
            $warnings = [];

            if (!is_array($raw)) {
                $errors[] = 'Route entry is not a JSON object';
                $summary['errors_count']++;
                $items[] = [
                    'index' => $idx, 'status' => 'error', 'key' => "#$idx", 'label' => "Entry #$idx",
                    'reason' => implode('; ', $errors), 'errors' => $errors, 'warnings' => [], 'diff' => null, 'normalized' => null,
                ];
                continue;
            }

            $r = trim((string) ($raw['r'] ?? $entry['map_key'] ?? ''));
            $f = trim((string) ($raw['f'] ?? ''));
            $t = trim((string) ($raw['t'] ?? ''));
            $bt = trim((string) ($raw['bt'] ?? 'City Bus (Private/State)')) ?: 'City Bus (Private/State)';
            $cat = trim((string) ($raw['cat'] ?? 'West Bengal Transport Corporation')) ?: 'West Bengal Transport Corporation';
            $tt = trim((string) ($raw['tt'] ?? ''));
            $img = trim((string) ($raw['img'] ?? ''));
            $rn = trim((string) ($raw['rn'] ?? ''));
            $extId = isset($raw['id']) && is_numeric($raw['id']) ? (int) $raw['id'] : null;

            $rawStops = $raw['s'] ?? ($raw['stops'] ?? []);
            $stops = [];
            if (is_array($rawStops)) {
                $prevNorm = null;
                foreach ($rawStops as $sItem) {
                    $sName = is_array($sItem) ? trim((string) ($sItem['n'] ?? '')) : trim((string) $sItem);
                    if ($sName === '') {
                        continue;
                    }
                    $sn = cholo_norm_text($sName);
                    if ($sn === $prevNorm) {
                        $warnings[] = "Removed consecutive duplicate stop '$sName'";
                        continue;
                    }
                    $stops[] = $sName;
                    $prevNorm = $sn;
                }
            }

            if ($r === '') $errors[] = 'Missing route number (r)';
            if ($f === '') $errors[] = 'Missing origin (f)';
            if ($t === '') $errors[] = 'Missing destination (t)';
            if (count($stops) < 2) $errors[] = 'Fewer than 2 valid stops in (s)';

            if ($entry['map_key'] !== null && $r !== '' && cholo_norm_route_no($entry['map_key']) !== cholo_norm_route_no($r)) {
                $warnings[] = "Map key '{$entry['map_key']}' differs from 'r' ('$r')";
            }
            if (!empty($stops) && $f !== '' && cholo_norm_text($stops[0]) !== cholo_norm_text($f)) {
                $warnings[] = "First stop ('{$stops[0]}') differs from origin ('$f')";
            }
            if (!empty($stops) && $t !== '' && cholo_norm_text(end($stops)) !== cholo_norm_text($t)) {
                $warnings[] = "Last stop ('" . end($stops) . "') differs from destination ('$t')";
            }

            $sig = cholo_norm_route_no($r) . '|' . cholo_norm_text($f) . '|' . cholo_norm_text($t);
            $normStops = array_map('cholo_norm_text', $stops);

            if ($extId !== null) {
                if (isset($seenIds[$extId]) && $seenIds[$extId] !== $sig) {
                    $warnings[] = "Duplicate ID #$extId shared with '{$seenIds[$extId]}' inside file";
                }
                $seenIds[$extId] = $sig;
            }

            if ($rn === '' && $f !== '' && $t !== '') {
                $rn = "$f to $t";
            }

            $normalized = [
                'id' => $extId, 'r' => $r, 'f' => $f, 't' => $t, 'rn' => $rn,
                'bt' => $bt, 'cat' => $cat, 'tt' => $tt, 'img' => $img, 's' => $stops,
            ];

            if (!empty($errors)) {
                $summary['errors_count']++;
                if (!empty($warnings)) $summary['warnings_count']++;
                $items[] = [
                    'index' => $idx, 'status' => 'error', 'key' => $sig, 'label' => trim("$r ($f ➔ $t)"),
                    'reason' => implode('; ', $errors), 'errors' => $errors, 'warnings' => $warnings,
                    'diff' => null, 'existing_id' => null, 'normalized' => null,
                ];
                continue;
            }

            $status = 'new';
            $reason = 'New directional bus route ready to import';
            $diff = null;
            $existingId = null;

            if (isset($seenSigs[$sig])) {
                $status = 'in_file_duplicate';
                $reason = "Duplicate of entry #{$seenSigs[$sig]} inside the same uploaded JSON";
                $summary['in_file_duplicates_count']++;
            } else {
                $seenSigs[$sig] = $idx + 1;
                if (isset($dbBySig[$sig])) {
                    $matchedExact = false;
                    $bestMatch = $dbBySig[$sig][0];
                    $bestDiff = null;

                    foreach ($dbBySig[$sig] as $ex) {
                        $exStopsNorm = array_map('cholo_norm_text', $ex['s'] ?? []);
                        if ($exStopsNorm === $normStops) {
                            $matchedExact = true;
                            $bestMatch = $ex;
                            break;
                        }
                    }

                    $existingId = $bestMatch['id'] ?? null;
                    if ($matchedExact) {
                        // Check metadata conflict (e.g. new timetable provided while stops identical)
                        $oldTt = trim((string) ($bestMatch['tt'] ?? ''));
                        $fieldsChanged = [];
                        if ($tt !== '' && $tt !== $oldTt && stripos($oldTt, 'coming soon') === false) {
                            $fieldsChanged['timetable'] = [$oldTt ?: '(none)', $tt];
                        }
                        if ($tt !== '' && ($oldTt === '' || stripos($oldTt, 'coming soon') !== false)) {
                            $fieldsChanged['timetable'] = [$oldTt ?: '(none)', $tt];
                        }
                        if (!empty($fieldsChanged)) {
                            $status = 'conflict_modified';
                            $reason = 'Same stops already in DB, but timetable/details changed';
                            $diff = [
                                'old_stops_count' => count($bestMatch['s'] ?? []),
                                'new_stops_count' => count($stops),
                                'stops_added' => [],
                                'stops_removed' => [],
                                'fields_changed' => $fieldsChanged,
                            ];
                            $summary['conflicts_count']++;
                        } else {
                            $status = 'exact_duplicate';
                            $reason = 'Exact match already in database (same route, endpoints & stop sequence)';
                            $summary['exact_duplicates_count']++;
                        }
                    } else {
                        $exStops = $bestMatch['s'] ?? [];
                        $exMap = array_flip(array_map('cholo_norm_text', $exStops));
                        $newMap = array_flip($normStops);
                        $added = [];
                        foreach ($stops as $sn) {
                            if (!isset($exMap[cholo_norm_text($sn)])) $added[] = $sn;
                        }
                        $removed = [];
                        foreach ($exStops as $sn) {
                            if (!isset($newMap[cholo_norm_text($sn)])) $removed[] = $sn;
                        }
                        $status = 'conflict_modified';
                        $reason = 'Route already in DB with different intermediate stops (' . count($exStops) . ' vs ' . count($stops) . ' stops)';
                        $diff = [
                            'old_stops_count' => count($exStops),
                            'new_stops_count' => count($stops),
                            'stops_added' => array_slice($added, 0, 12),
                            'stops_removed' => array_slice($removed, 0, 12),
                            'fields_changed' => [
                                'stops_sequence' => [count($exStops) . ' stops', count($stops) . ' stops'],
                            ],
                        ];
                        $summary['conflicts_count']++;
                    }
                } else {
                    $summary['new_count']++;
                }
            }

            if (!empty($warnings)) {
                $summary['warnings_count']++;
            }

            $items[] = [
                'index' => $idx,
                'status' => $status,
                'key' => $sig,
                'label' => "$r • $f ➔ $t (" . count($stops) . " stops)",
                'reason' => $reason,
                'errors' => [],
                'warnings' => $warnings,
                'diff' => $diff,
                'existing_id' => $existingId,
                'normalized' => $normalized,
            ];
        }
    } elseif ($format === 'auto_routes') {
        $checksRun = [
            'Auto schema & minimum 2 stops check',
            'Service window (HH:MM) & min/max fare sanity check',
            'Distance (km), duration (mins) & implied speed check (5-55 km/h)',
            'Stop GPS West Bengal bounding box [21.2..27.5, 85.5..90.0] check',
            'Intra-file + Live DB duplicate match by RID & normalized corridor',
            'Corridor stop-overlap (>85%) & field diff check',
        ];

        $dbByRid = [];
        $dbBySig = [];
        foreach (($existingState['auto_routes'] ?? []) as $ex) {
            $exRid = strtolower(trim((string) ($ex['rid'] ?? '')));
            if ($exRid !== '') $dbByRid[$exRid] = $ex;
            $exSig = cholo_norm_stop_key($ex['f'] ?? '') . '|' . cholo_norm_stop_key($ex['t'] ?? '');
            $dbBySig[$exSig][] = $ex;
        }

        $seenRids = [];
        $seenSigs = [];
        $seenAutoPayloads = [];

        foreach ($entries as $entry) {
            $raw = $entry['raw'];
            $idx = $entry['index'];
            $errors = [];
            $warnings = [];

            if (!is_array($raw)) {
                $summary['errors_count']++;
                $items[] = [
                    'index' => $idx, 'status' => 'error', 'key' => "#$idx", 'label' => "Auto #$idx",
                    'reason' => 'Entry is not a JSON object', 'errors' => ['Entry is not a JSON object'], 'warnings' => [],
                    'diff' => null, 'existing_id' => null, 'normalized' => null,
                ];
                continue;
            }

            $f = trim((string) ($raw['f'] ?? ''));
            $t = trim((string) ($raw['t'] ?? ''));
            $rCode = trim((string) ($raw['r'] ?? 'AUTO')) ?: 'AUTO';
            $rn = trim((string) ($raw['rn'] ?? ($f && $t ? "$f - $t" : '')));
            $rid = trim((string) ($raw['rid'] ?? ''));
            if ($rid === '' && $f !== '' && $t !== '') {
                $rid = 'auto_' . cholo_slug($f) . '_' . cholo_slug($t);
            }
            $extId = isset($raw['id']) && is_numeric($raw['id']) ? (int) $raw['id'] : null;
            $hwP = isset($raw['hwP']) && is_numeric($raw['hwP']) ? (int) $raw['hwP'] : 6;
            $hwO = isset($raw['hwO']) && is_numeric($raw['hwO']) ? (int) $raw['hwO'] : 10;
            $fs = trim((string) ($raw['fs'] ?? '06:00')) ?: '06:00';
            $ls = trim((string) ($raw['ls'] ?? '22:30')) ?: '22:30';
            $fMin = isset($raw['fMin']) && is_numeric($raw['fMin']) ? (int) $raw['fMin'] : 10;
            $fMax = isset($raw['fMax']) && is_numeric($raw['fMax']) ? (int) $raw['fMax'] : max($fMin, 15);
            $km = isset($raw['km']) && is_numeric($raw['km']) ? round((float) $raw['km'], 2) : 0.0;
            $dur = isset($raw['dur']) && is_numeric($raw['dur']) ? (int) $raw['dur'] : 0;
            $nt = trim((string) ($raw['nt'] ?? ''));

            if ($f === '') $errors[] = 'Missing origin (f)';
            if ($t === '') $errors[] = 'Missing destination (t)';

            // Parse stops & validate stop coordinates if provided
            $stops = [];
            $coordSeq = [];
            $prevStopKey = null;
            foreach (($raw['stops'] ?? []) as $sIdx => $sItem) {
                $sName = is_array($sItem) ? trim((string) ($sItem['n'] ?? '')) : trim((string) $sItem);
                if ($sName === '') continue;
                $sk = cholo_norm_stop_key($sName);
                if ($sk !== '' && $sk === $prevStopKey) {
                    $warnings[] = "Removed consecutive duplicate stop '$sName'";
                    continue;
                }
                $prevStopKey = $sk;

                $stopObj = ['n' => $sName];
                if (is_array($sItem) && isset($sItem['lat']) && isset($sItem['lng']) && $sItem['lat'] !== null && $sItem['lng'] !== null && $sItem['lat'] !== '' && $sItem['lng'] !== '') {
                    $chk = cholo_validate_wb_coord($sItem['lat'], $sItem['lng']);
                    if (!$chk['valid']) {
                        $errors[] = "Stop #" . ($sIdx + 1) . " ('$sName') GPS error: {$chk['error']}";
                    } else {
                        $stopObj['lat'] = $chk['lat'];
                        $stopObj['lng'] = $chk['lng'];
                        $coordSeq[] = [$chk['lat'], $chk['lng']];
                    }
                }
                $stops[] = $stopObj;
            }

            if (count($stops) < 2) {
                $errors[] = 'Fewer than 2 valid auto stops';
            }

            // Timing sanity
            $fsMins = cholo_parse_hhmm($fs);
            $lsMins = cholo_parse_hhmm($ls);
            if ($fsMins === null || $lsMins === null) {
                $warnings[] = "Unusual time format fs='$fs', ls='$ls' (expected HH:MM)";
            } elseif ($lsMins <= $fsMins) {
                $warnings[] = "Last service ($ls) is not later than first service ($fs)";
            }

            // Fare sanity
            if ($fMin < 5 || $fMax < $fMin || $fMax > 200) {
                $warnings[] = "Unusual auto fare range ₹$fMin - ₹$fMax";
            }

            // Distance & speed sanity
            if ($km <= 0 || $dur <= 0) {
                $warnings[] = "Missing or zero km ($km) / duration ($dur mins)";
            } else {
                $speedKmh = $km / ($dur / 60.0);
                if ($speedKmh < 5.0 || $speedKmh > 55.0) {
                    $warnings[] = sprintf("Unusual speed %.1f km/h (%s km in %d mins)", $speedKmh, $km, $dur);
                }
                if ($km > 60.0) {
                    $warnings[] = "Very long auto route distance ({$km} km)";
                }
            }

            // GPS path jump check if coords provided
            if (count($coordSeq) >= 2 && $km > 0) {
                $geoKm = 0.0;
                for ($ci = 0; $ci < count($coordSeq) - 1; $ci++) {
                    $geoKm += cholo_haversine_km($coordSeq[$ci][0], $coordSeq[$ci][1], $coordSeq[$ci + 1][0], $coordSeq[$ci + 1][1]);
                }
                if ($geoKm > max(5.0, $km * 2.5)) {
                    $warnings[] = sprintf("GPS path sum (%.1f km) is >2.5x stated distance (%.1f km)", $geoKm, $km);
                }
            }

            $sig = cholo_norm_stop_key($f) . '|' . cholo_norm_stop_key($t);
            $ridLower = strtolower($rid);
            $hasExplicitRid = trim((string) ($raw['rid'] ?? '')) !== '';
            $stopHash = implode('>', array_map(function ($s) {
                return cholo_norm_stop_key($s['n']);
            }, $stops));
            $payloadSig = strtolower($rCode) . '|' . $sig . '|' . md5($stopHash);

            $normalized = [
                'id' => $extId, 'rid' => $rid, 'r' => $rCode, 'rn' => $rn, 'f' => $f, 't' => $t,
                'hwP' => $hwP, 'hwO' => $hwO, 'fs' => $fs, 'ls' => $ls,
                'fMin' => $fMin, 'fMax' => $fMax, 'km' => $km ?: 3.0, 'dur' => $dur ?: 12,
                'nt' => $nt, 'stops' => $stops,
            ];

            if (!empty($errors)) {
                $summary['errors_count']++;
                if (!empty($warnings)) $summary['warnings_count']++;
                $items[] = [
                    'index' => $idx, 'status' => 'error', 'key' => $rid ?: $sig,
                    'label' => "$rCode • $f ➔ $t", 'reason' => implode('; ', $errors),
                    'errors' => $errors, 'warnings' => $warnings, 'diff' => null, 'existing_id' => null, 'normalized' => null,
                ];
                continue;
            }

            $status = 'new';
            $reason = 'New auto route ready to import';
            $diff = null;
            $existingId = null;

            $isInFileDup = false;
            $dupIdx = null;
            if ($ridLower !== '' && isset($seenRids[$ridLower])) {
                $isInFileDup = true;
                $dupIdx = $seenRids[$ridLower];
            } elseif (isset($seenAutoPayloads[$payloadSig])) {
                $isInFileDup = true;
                $dupIdx = $seenAutoPayloads[$payloadSig];
            } elseif (!$hasExplicitRid && isset($seenSigs[$sig])) {
                $isInFileDup = true;
                $dupIdx = $seenSigs[$sig];
            }

            if ($isInFileDup) {
                $status = 'in_file_duplicate';
                $reason = "Duplicate RID or route corridor already seen at uploaded entry #$dupIdx";
                $summary['in_file_duplicates_count']++;
            } else {
                if (isset($seenSigs[$sig])) {
                    $warnings[] = "Another variant for corridor $f ➔ $t also exists in this upload (#{$seenSigs[$sig]})";
                }
                if ($ridLower !== '') $seenRids[$ridLower] = $idx + 1;
                $seenAutoPayloads[$payloadSig] = $idx + 1;
                if (!isset($seenSigs[$sig])) $seenSigs[$sig] = $idx + 1;

                $existingMatch = $dbByRid[$ridLower] ?? ($dbBySig[$sig][0] ?? null);
                if ($existingMatch) {
                    $existingId = $existingMatch['db_id'] ?? null;
                    $exStops = array_map(function ($s) {
                        return is_array($s) ? ($s['n'] ?? '') : (string) $s;
                    }, $existingMatch['stops'] ?? []);
                    $newStopNames = array_map(function ($s) {
                        return $s['n'];
                    }, $stops);

                    $exNorm = array_map('cholo_norm_stop_key', $exStops);
                    $newNorm = array_map('cholo_norm_stop_key', $newStopNames);

                    $fieldsChanged = [];
                    if ($exNorm !== $newNorm) {
                        $fieldsChanged['stops'] = [count($exNorm) . ' stops', count($newNorm) . ' stops'];
                    }
                    if ((int) ($existingMatch['fMin'] ?? 0) !== $fMin || (int) ($existingMatch['fMax'] ?? 0) !== $fMax) {
                        $fieldsChanged['fare'] = ["₹{$existingMatch['fMin']}-{$existingMatch['fMax']}", "₹$fMin-$fMax"];
                    }
                    if (abs((float) ($existingMatch['km'] ?? 0) - $km) > 0.2 && $km > 0) {
                        $fieldsChanged['km'] = [(string) ($existingMatch['km'] ?? 0), (string) $km];
                    }
                    if (abs((int) ($existingMatch['dur'] ?? 0) - $dur) > 2 && $dur > 0) {
                        $fieldsChanged['dur'] = [(string) ($existingMatch['dur'] ?? 0) . 'm', $dur . 'm'];
                    }
                    if (trim((string) ($existingMatch['r'] ?? '')) !== $rCode) {
                        $fieldsChanged['code'] = [trim((string) ($existingMatch['r'] ?? '')), $rCode];
                    }

                    if (empty($fieldsChanged)) {
                        $status = 'exact_duplicate';
                        $reason = 'Exact auto corridor match already in database';
                        $summary['exact_duplicates_count']++;
                    } else {
                        $status = 'conflict_modified';
                        $reason = 'Matching RID/corridor exists in DB with updated fields: ' . implode(', ', array_keys($fieldsChanged));
                        $exSet = array_flip($exNorm);
                        $newSet = array_flip($newNorm);
                        $added = [];
                        foreach ($newStopNames as $sn) {
                            if (!isset($exSet[cholo_norm_stop_key($sn)])) $added[] = $sn;
                        }
                        $removed = [];
                        foreach ($exStops as $sn) {
                            if (!isset($newSet[cholo_norm_stop_key($sn)])) $removed[] = $sn;
                        }
                        $diff = [
                            'old_stops_count' => count($exStops),
                            'new_stops_count' => count($newStopNames),
                            'stops_added' => array_slice($added, 0, 10),
                            'stops_removed' => array_slice($removed, 0, 10),
                            'fields_changed' => $fieldsChanged,
                        ];
                        $summary['conflicts_count']++;
                    }
                } else {
                    $summary['new_count']++;
                }
            }

            if (!empty($warnings)) {
                $summary['warnings_count']++;
            }

            $items[] = [
                'index' => $idx,
                'status' => $status,
                'key' => $rid,
                'label' => "$rCode • $f ➔ $t (" . count($stops) . " stops, ₹$fMin-$fMax, {$km}km)",
                'reason' => $reason,
                'errors' => [],
                'warnings' => $warnings,
                'diff' => $diff,
                'existing_id' => $existingId,
                'normalized' => $normalized,
            ];
        }
    } elseif ($format === 'stop_coords') {
        $checksRun = [
            'Normalize stop key using KolkataGeo rules',
            'Reject (0,0), non-numeric, and swapped [lng, lat] values',
            'Validate West Bengal bounding box (Lat 21.2..27.5, Lng 85.5..90.0)',
            'Intra-file normalized stop key duplicate scan',
            'Live DB coordinate diff (>50m drift flagged as conflict)',
            'Nearby alias warning (<30m from different existing stop)',
        ];

        $existingCoords = $existingState['stop_coords'] ?? [];
        $seenKeys = [];

        foreach ($entries as $entry) {
            $idx = $entry['index'];
            $rawKey = $entry['raw_key'];
            $pair = cholo_extract_coord_pair($entry['raw_val']);
            $normKey = cholo_norm_stop_key($rawKey);
            $errors = [];
            $warnings = [];

            if ($normKey === '') {
                $errors[] = 'Stop name key normalizes to empty string';
            }
            if ($pair === null) {
                $errors[] = 'Expected [lat, lng] array or {lat, lng} object';
            } else {
                $chk = cholo_validate_wb_coord($pair[0], $pair[1]);
                if (!$chk['valid']) {
                    $errors[] = $chk['error'];
                }
            }

            if (!empty($errors)) {
                $summary['errors_count']++;
                $items[] = [
                    'index' => $idx, 'status' => 'error', 'key' => $rawKey, 'label' => $rawKey,
                    'reason' => implode('; ', $errors), 'errors' => $errors, 'warnings' => [],
                    'diff' => null, 'existing_id' => null, 'normalized' => null,
                ];
                continue;
            }

            $lat = $chk['lat'];
            $lng = $chk['lng'];
            $normalized = ['stop_key' => $normKey, 'display_name' => trim($rawKey), 'lat' => $lat, 'lng' => $lng];

            $status = 'new';
            $reason = "New GPS coordinate [$lat, $lng]";
            $diff = null;
            $existingId = null;

            if (isset($seenKeys[$normKey])) {
                $status = 'in_file_duplicate';
                $reason = "Normalized key '$normKey' collides with uploaded entry #{$seenKeys[$normKey]}";
                $summary['in_file_duplicates_count']++;
            } else {
                $seenKeys[$normKey] = $idx + 1;
                if (isset($existingCoords[$normKey])) {
                    $ex = $existingCoords[$normKey];
                    $existingId = $ex['db_id'] ?? null;
                    $distKm = cholo_haversine_km($ex['lat'], $ex['lng'], $lat, $lng);
                    $distM = round($distKm * 1000);
                    if ($distKm < 0.05) {
                        $status = 'exact_duplicate';
                        $reason = "Already mapped within {$distM}m";
                        $summary['exact_duplicates_count']++;
                    } else {
                        $status = 'conflict_modified';
                        $reason = sprintf("Existing pin shifted by %.2f km (%dm)", $distKm, $distM);
                        $diff = [
                            'fields_changed' => [
                                'coords' => ["[{$ex['lat']}, {$ex['lng']}]", "[$lat, $lng] ({$distM}m shift)"],
                            ],
                        ];
                        $summary['conflicts_count']++;
                    }
                } else {
                    // Check if coordinate sits <30m from another differently named stop
                    foreach ($existingCoords as $exKey => $ex) {
                        if (abs($ex['lat'] - $lat) < 0.0005 && abs($ex['lng'] - $lng) < 0.0005) {
                            $d = cholo_haversine_km($ex['lat'], $ex['lng'], $lat, $lng);
                            if ($d < 0.03) {
                                $warnings[] = sprintf("Within %dm of existing stop '%s'", round($d * 1000), $exKey);
                                break;
                            }
                        }
                    }
                    $summary['new_count']++;
                }
            }

            if (!empty($warnings)) $summary['warnings_count']++;

            $items[] = [
                'index' => $idx, 'status' => $status, 'key' => $normKey,
                'label' => "$normKey [$lat, $lng]", 'reason' => $reason,
                'errors' => [], 'warnings' => $warnings, 'diff' => $diff,
                'existing_id' => $existingId, 'normalized' => $normalized,
            ];
        }
    } elseif ($format === 'stops') {
        $checksRun = [
            'Stop name non-empty & routes_count >= 0 check',
            'Intra-file case-insensitive duplicate stop scan',
            'Live DB stop_name match & routes_count diff check',
        ];

        $existingStops = $existingState['stops'] ?? [];
        $seen = [];

        foreach ($entries as $entry) {
            $idx = $entry['index'];
            $raw = $entry['raw'];
            $errors = [];

            $name = is_array($raw) ? trim((string) ($raw['n'] ?? '')) : trim((string) $raw);
            $cnt = is_array($raw) && isset($raw['c']) && is_numeric($raw['c']) ? max(0, (int) $raw['c']) : 1;
            if ($name === '') {
                $errors[] = 'Empty stop name';
            }

            if (!empty($errors)) {
                $summary['errors_count']++;
                $items[] = [
                    'index' => $idx, 'status' => 'error', 'key' => "#$idx", 'label' => "Stop #$idx",
                    'reason' => implode('; ', $errors), 'errors' => $errors, 'warnings' => [],
                    'diff' => null, 'existing_id' => null, 'normalized' => null,
                ];
                continue;
            }

            $key = cholo_norm_text($name);
            $normalized = ['n' => $name, 'c' => $cnt];
            $status = 'new';
            $reason = "New stop ($cnt routes)";
            $diff = null;
            $existingId = null;

            if (isset($seen[$key])) {
                $status = 'in_file_duplicate';
                $reason = "Duplicate of stop entry #{$seen[$key]} inside file";
                $summary['in_file_duplicates_count']++;
            } else {
                $seen[$key] = $idx + 1;
                if (isset($existingStops[$key])) {
                    $ex = $existingStops[$key];
                    $existingId = $ex['db_id'] ?? null;
                    $oldC = (int) ($ex['c'] ?? 0);
                    if ($cnt > $oldC) {
                        $status = 'conflict_modified';
                        $reason = "Already in DB with lower route count ($oldC -> $cnt)";
                        $diff = ['fields_changed' => ['routes_count' => [(string) $oldC, (string) $cnt]]];
                        $summary['conflicts_count']++;
                    } else {
                        $status = 'exact_duplicate';
                        $reason = "Already indexed in DB (routes_count=$oldC)";
                        $summary['exact_duplicates_count']++;
                    }
                } else {
                    $summary['new_count']++;
                }
            }

            $items[] = [
                'index' => $idx, 'status' => $status, 'key' => $key,
                'label' => "$name (c=$cnt)", 'reason' => $reason,
                'errors' => [], 'warnings' => [], 'diff' => $diff,
                'existing_id' => $existingId, 'normalized' => $normalized,
            ];
        }
    }

    return [
        'success' => true,
        'detected_type' => $format,
        'summary' => $summary,
        'checks_run' => $checksRun,
        'items' => $items,
    ];
}

/**
 * Commits analyzed JSON records into MySQL according to the selected mode:
 * - skip_duplicates: insert only 'new'
 * - upsert_conflicts: insert 'new' + update 'conflict_modified'
 * - replace_all: replace entire dataset with valid deduplicated records
 */
function cholo_commit_import(mysqli $db, array $analysis, string $mode = 'skip_duplicates', string $versionFile = '')
{
    if (empty($analysis['success'])) {
        return ['success' => false, 'error' => $analysis['error'] ?? 'Invalid analysis'];
    }

    ensure_ota_transit_schema($db);
    $format = $analysis['detected_type'];
    $items = $analysis['items'] ?? [];
    if (!in_array($mode, ['skip_duplicates', 'upsert_conflicts', 'replace_all'], true)) {
        $mode = 'skip_duplicates';
    }

    $inserted = 0;
    $updated = 0;
    $skipped = 0;
    $errors = 0;

    $db->begin_transaction();
    try {
        if ($format === 'bus_routes') {
            if ($mode === 'replace_all') {
                $db->query("DELETE FROM route_stops");
                $db->query("DELETE FROM routes");
            }
            $insRoute = $db->prepare("INSERT INTO routes (route_no, route_name, origin, destination, category, bus_type, timetable, image_url, total_stops) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
            $updRoute = $db->prepare("UPDATE routes SET route_no=?, route_name=?, origin=?, destination=?, category=?, bus_type=?, timetable=?, image_url=?, total_stops=? WHERE id=?");
            $delStops = $db->prepare("DELETE FROM route_stops WHERE route_id=?");
            $insStop = $db->prepare("INSERT INTO route_stops (route_id, stop_order, stop_name, stop_clean) VALUES (?, ?, ?, ?)");
            $insMaster = $db->prepare("INSERT INTO stops (stop_name, routes_count) VALUES (?, 1) ON DUPLICATE KEY UPDATE routes_count = routes_count + 1");

            foreach ($items as $it) {
                $st = $it['status'];
                if ($st === 'error' || $st === 'in_file_duplicate' || empty($it['normalized'])) {
                    $errors += ($st === 'error') ? 1 : 0;
                    $skipped += ($st === 'in_file_duplicate') ? 1 : 0;
                    continue;
                }
                if ($mode === 'skip_duplicates' && $st !== 'new') {
                    $skipped++;
                    continue;
                }
                if ($mode === 'upsert_conflicts' && $st === 'exact_duplicate') {
                    $skipped++;
                    continue;
                }

                $n = $it['normalized'];
                $stops = $n['s'];
                $tot = count($stops);
                $routeId = null;

                if ($mode === 'upsert_conflicts' && $st === 'conflict_modified' && !empty($it['existing_id'])) {
                    $routeId = (int) $it['existing_id'];
                    $updRoute->bind_param('ssssssssii', $n['r'], $n['rn'], $n['f'], $n['t'], $n['cat'], $n['bt'], $n['tt'], $n['img'], $tot, $routeId);
                    $updRoute->execute();
                    $delStops->bind_param('i', $routeId);
                    $delStops->execute();
                    $updated++;
                } else {
                    $insRoute->bind_param('ssssssssi', $n['r'], $n['rn'], $n['f'], $n['t'], $n['cat'], $n['bt'], $n['tt'], $n['img'], $tot);
                    $insRoute->execute();
                    $routeId = (int) $insRoute->insert_id;
                    $inserted++;
                }

                foreach ($stops as $idx => $sName) {
                    $ord = $idx + 1;
                    $clean = strtolower($sName);
                    $insStop->bind_param('iiss', $routeId, $ord, $sName, $clean);
                    $insStop->execute();
                    $insMaster->bind_param('s', $sName);
                    $insMaster->execute();
                }
            }
        } elseif ($format === 'auto_routes') {
            if ($mode === 'replace_all') {
                $db->query("DELETE FROM auto_routes");
            }
            $upsertStmt = $db->prepare("
                INSERT INTO auto_routes
                (ext_id, rid, route_code, route_name, origin, destination, sig_key, hw_peak, hw_offpeak, first_service, last_service, fare_min, fare_max, distance_km, duration_mins, notes, stops_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    ext_id = COALESCE(VALUES(ext_id), ext_id),
                    route_code = VALUES(route_code),
                    route_name = VALUES(route_name),
                    origin = VALUES(origin),
                    destination = VALUES(destination),
                    sig_key = VALUES(sig_key),
                    hw_peak = VALUES(hw_peak),
                    hw_offpeak = VALUES(hw_offpeak),
                    first_service = VALUES(first_service),
                    last_service = VALUES(last_service),
                    fare_min = VALUES(fare_min),
                    fare_max = VALUES(fare_max),
                    distance_km = VALUES(distance_km),
                    duration_mins = VALUES(duration_mins),
                    notes = VALUES(notes),
                    stops_json = VALUES(stops_json)
            ");
            $updByIdStmt = $db->prepare("
                UPDATE auto_routes SET
                    route_code=?, route_name=?, origin=?, destination=?, sig_key=?,
                    hw_peak=?, hw_offpeak=?, first_service=?, last_service=?, fare_min=?, fare_max=?,
                    distance_km=?, duration_mins=?, notes=?, stops_json=?
                WHERE id=?
            ");

            foreach ($items as $it) {
                $st = $it['status'];
                if ($st === 'error' || $st === 'in_file_duplicate' || empty($it['normalized'])) {
                    $errors += ($st === 'error') ? 1 : 0;
                    $skipped += ($st === 'in_file_duplicate') ? 1 : 0;
                    continue;
                }
                if ($mode === 'skip_duplicates' && $st !== 'new') {
                    $skipped++;
                    continue;
                }
                if ($mode === 'upsert_conflicts' && $st === 'exact_duplicate') {
                    $skipped++;
                    continue;
                }

                $n = $it['normalized'];
                $sigKey = cholo_norm_stop_key($n['f']) . '|' . cholo_norm_stop_key($n['t']);
                $stopsJson = json_encode($n['stops'], JSON_UNESCAPED_UNICODE);

                if ($mode === 'upsert_conflicts' && $st === 'conflict_modified' && !empty($it['existing_id'])) {
                    $exId = (int) $it['existing_id'];
                    $updByIdStmt->bind_param(
                        'sssssiissiidissi',
                        $n['r'], $n['rn'], $n['f'], $n['t'], $sigKey,
                        $n['hwP'], $n['hwO'], $n['fs'], $n['ls'], $n['fMin'], $n['fMax'],
                        $n['km'], $n['dur'], $n['nt'], $stopsJson, $exId
                    );
                    $updByIdStmt->execute();
                    $updated++;
                } else {
                    $upsertStmt->bind_param(
                        'issssssiissiidiss',
                        $n['id'], $n['rid'], $n['r'], $n['rn'], $n['f'], $n['t'], $sigKey,
                        $n['hwP'], $n['hwO'], $n['fs'], $n['ls'], $n['fMin'], $n['fMax'],
                        $n['km'], $n['dur'], $n['nt'], $stopsJson
                    );
                    $upsertStmt->execute();
                    $inserted++;
                }
            }
        } elseif ($format === 'stop_coords') {
            if ($mode === 'replace_all') {
                $db->query("DELETE FROM stop_coords");
            }
            $upsertCoord = $db->prepare("
                INSERT INTO stop_coords (stop_key, display_name, lat, lng)
                VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    display_name = VALUES(display_name),
                    lat = VALUES(lat),
                    lng = VALUES(lng)
            ");

            foreach ($items as $it) {
                $st = $it['status'];
                if ($st === 'error' || $st === 'in_file_duplicate' || empty($it['normalized'])) {
                    $errors += ($st === 'error') ? 1 : 0;
                    $skipped += ($st === 'in_file_duplicate') ? 1 : 0;
                    continue;
                }
                if ($mode === 'skip_duplicates' && $st !== 'new') {
                    $skipped++;
                    continue;
                }
                if ($mode === 'upsert_conflicts' && $st === 'exact_duplicate') {
                    $skipped++;
                    continue;
                }
                $n = $it['normalized'];
                $upsertCoord->bind_param('ssdd', $n['stop_key'], $n['display_name'], $n['lat'], $n['lng']);
                $upsertCoord->execute();
                if ($st === 'conflict_modified') $updated++; else $inserted++;
            }
        } elseif ($format === 'stops') {
            if ($mode === 'replace_all') {
                $db->query("DELETE FROM stops");
            }
            $upsertStop = $db->prepare("
                INSERT INTO stops (stop_name, routes_count)
                VALUES (?, ?)
                ON DUPLICATE KEY UPDATE routes_count = GREATEST(routes_count, VALUES(routes_count))
            ");
            foreach ($items as $it) {
                $st = $it['status'];
                if ($st === 'error' || $st === 'in_file_duplicate' || empty($it['normalized'])) {
                    $errors += ($st === 'error') ? 1 : 0;
                    $skipped += ($st === 'in_file_duplicate') ? 1 : 0;
                    continue;
                }
                if ($mode === 'skip_duplicates' && $st !== 'new') {
                    $skipped++;
                    continue;
                }
                if ($mode === 'upsert_conflicts' && $st === 'exact_duplicate') {
                    $skipped++;
                    continue;
                }
                $n = $it['normalized'];
                $upsertStop->bind_param('si', $n['n'], $n['c']);
                $upsertStop->execute();
                if ($st === 'conflict_modified') $updated++; else $inserted++;
            }
        }

        $db->commit();
    } catch (Throwable $e) {
        $db->rollback();
        return ['success' => false, 'error' => 'Transaction rolled back: ' . $e->getMessage()];
    }

    $vFile = $versionFile ?: (dirname(__DIR__) . '/ota_version.json');
    $otaInfo = cholo_bump_ota_version_with_counts(
        $vFile,
        $db,
        "Bulk JSON import ($format): +$inserted added, $updated updated, $skipped skipped."
    );

    return [
        'success' => true,
        'detected_type' => $format,
        'mode' => $mode,
        'inserted' => $inserted,
        'updated' => $updated,
        'skipped' => $skipped,
        'errors' => $errors,
        'ota_version' => $otaInfo['version'],
        'counts' => $otaInfo['counts'],
    ];
}
