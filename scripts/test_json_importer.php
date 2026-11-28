<?php
require_once __DIR__ . '/../admin/json_importer.php';

function assert_true($cond, $msg)
{
    if (!$cond) {
        fwrite(STDERR, "ASSERTION FAILED: $msg\n");
        exit(1);
    }
}

echo "Running CholoKolkata JSON Importer & Duplicate Checker Tests...\n";

// 1. Auto routes: duplicate, modified conflict, bad GPS, timing/speed warnings, net new
$existingAuto = [
    [
        'db_id' => 1,
        'id' => 70001,
        'rid' => 'auto_r91',
        'r' => 'A-91',
        'f' => 'Phoolbagan',
        't' => 'Karunamoyee',
        'fMin' => 12,
        'fMax' => 15,
        'km' => 4.6,
        'dur' => 15,
        'fs' => '06:00',
        'ls' => '22:30',
        'stops' => [['n' => 'Phoolbagan'], ['n' => 'Bengal Chemical'], ['n' => 'Karunamoyee']],
    ],
];

$autoUpload = [
    // Exact duplicate
    [
        'rid' => 'auto_r91',
        'r' => 'A-91',
        'f' => 'Phoolbagan',
        't' => 'Karunamoyee',
        'fMin' => 12,
        'fMax' => 15,
        'km' => 4.6,
        'dur' => 15,
        'fs' => '06:00',
        'ls' => '22:30',
        'stops' => [['n' => 'Phoolbagan'], ['n' => 'Bengal Chemical'], ['n' => 'Karunamoyee']],
    ],
    // In-file duplicate of entry #1
    [
        'rid' => 'auto_r91',
        'r' => 'A-91',
        'f' => 'Phoolbagan',
        't' => 'Karunamoyee',
        'stops' => [['n' => 'Phoolbagan'], ['n' => 'Karunamoyee']],
    ],
    // Conflict (same origin+dest, different stops/fare)
    [
        'rid' => 'auto_phoolbagan_karunamoyee_alt',
        'r' => 'A-91X',
        'f' => 'Phoolbagan',
        't' => 'Karunamoyee',
        'fMin' => 15,
        'fMax' => 20,
        'km' => 5.0,
        'dur' => 18,
        'stops' => [['n' => 'Phoolbagan'], ['n' => 'Salt Lake Stadium'], ['n' => 'Karunamoyee']],
    ],
    // Bad swapped coordinates error
    [
        'rid' => 'auto_bad_coords',
        'f' => 'Esplanade',
        't' => 'Park Street',
        'stops' => [
            ['n' => 'Esplanade', 'lat' => 88.35, 'lng' => 22.56],
            ['n' => 'Park Street', 'lat' => 22.55, 'lng' => 88.35],
        ],
    ],
    // Valid net new with unrealistic speed warning
    [
        'rid' => 'auto_new_airport',
        'r' => 'A-22',
        'f' => 'Airport',
        't' => 'Chinar Park',
        'fMin' => 15,
        'fMax' => 20,
        'km' => 3.5,
        'dur' => 2, // 105 km/h warning
        'fs' => '05:30',
        'ls' => '22:30',
        'stops' => [
            ['n' => 'Airport', 'lat' => 22.6547, 'lng' => 88.4467],
            ['n' => 'Chinar Park', 'lat' => 22.6280, 'lng' => 88.4410],
        ],
    ],
];

$resAuto = cholo_analyze_upload($autoUpload, ['auto_routes' => $existingAuto], 'auto');
assert_true($resAuto['success'] === true, 'Auto analysis should succeed');
assert_true($resAuto['detected_type'] === 'auto_routes', 'Should detect auto_routes');
assert_true($resAuto['summary']['exact_duplicates_count'] === 1, 'Expected 1 exact DB dup');
assert_true($resAuto['summary']['in_file_duplicates_count'] === 1, 'Expected 1 in-file dup');
assert_true($resAuto['summary']['conflicts_count'] === 1, 'Expected 1 modified conflict');
assert_true($resAuto['summary']['errors_count'] === 1, 'Expected 1 GPS coord error');
assert_true($resAuto['summary']['new_count'] === 1, 'Expected 1 net new auto route');
assert_true($resAuto['summary']['warnings_count'] >= 1, 'Expected speed warning');

// 2. Bus routes: detect exact dup, return leg allowed as new, conflict on stops
$existingBus = [
    [
        'id' => 101,
        'r' => '215A',
        'f' => 'Howrah Station',
        't' => 'Sector V',
        'tt' => '06:00 AM - 09:30 PM',
        's' => ['Howrah Station', 'Esplanade', 'Ultadanga', 'Sector V'],
    ],
];
$busUpload = [
    '215A' => [
        // Exact dup
        ['r' => '215A', 'f' => 'Howrah Station', 't' => 'Sector V', 'tt' => '06:00 AM - 09:30 PM', 's' => ['Howrah Station', 'Esplanade', 'Ultadanga', 'Sector V']],
        // Return leg is NEW!
        ['r' => '215A', 'f' => 'Sector V', 't' => 'Howrah Station', 's' => ['Sector V', 'Ultadanga', 'Esplanade', 'Howrah Station']],
    ],
    'AC-54' => [
        ['r' => 'AC-54', 'f' => 'Howrah Station', 't' => 'Ballygunge Station', 's' => ['Howrah Station', 'Gariahat', 'Ballygunge Station']],
    ],
];
$resBus = cholo_analyze_upload($busUpload, ['bus_routes' => $existingBus], 'auto');
assert_true($resBus['detected_type'] === 'bus_routes', 'Should detect bus_routes');
assert_true($resBus['summary']['exact_duplicates_count'] === 1, 'Expected 1 exact bus dup');
assert_true($resBus['summary']['new_count'] === 2, 'Expected return leg + AC-54 as 2 new');

// 3. Stop coords: WB bounds + <50m dup + shifted pin conflict + nearby warning
$existingCoords = [
    'esplanade' => ['db_id' => 1, 'display_name' => 'esplanade', 'lat' => 22.5645, 'lng' => 88.3524],
    'ultadanga' => ['db_id' => 2, 'display_name' => 'ultadanga', 'lat' => 22.5975, 'lng' => 88.3887],
];
$coordsUpload = [
    'Esplanade' => [22.56452, 88.35241],        // exact dup (<50m)
    'Ultadanga' => [22.6050, 88.3950],          // moved pin conflict (>50m)
    'Esplanade Gate' => [22.56451, 88.35241],   // new stop, <30m from esplanade -> warning
    'Null Stop' => [0, 0],                      // error
    'Swapped' => [88.40, 22.60],                // error
];
$resCoords = cholo_analyze_upload($coordsUpload, ['stop_coords' => $existingCoords], 'auto');
assert_true($resCoords['detected_type'] === 'stop_coords', 'Should detect stop_coords');
assert_true($resCoords['summary']['exact_duplicates_count'] === 1, 'Expected 1 exact coord dup');
assert_true($resCoords['summary']['conflicts_count'] === 1, 'Expected 1 shifted pin conflict');
assert_true($resCoords['summary']['new_count'] === 1, 'Expected 1 new coord with nearby warning');
assert_true($resCoords['summary']['errors_count'] === 2, 'Expected 2 coord errors');
assert_true($resCoords['summary']['warnings_count'] >= 1, 'Expected nearby alias warning');

// 4. Real dataset sanity check against ota_data seed files
$realAutoSeed = json_decode(file_get_contents(__DIR__ . '/../ota_data/kolkata_auto_routes.json'), true);
$subsetPath = __DIR__ . '/../kolkata-auto-routes.json';
if (file_exists($subsetPath)) {
    $realAutoSubset = json_decode(file_get_contents($subsetPath), true);
    $resReal = cholo_analyze_upload($realAutoSubset, ['auto_routes' => $realAutoSeed], 'auto');
    assert_true($resReal['success'] === true, 'Real auto check should succeed');
    assert_true($resReal['summary']['errors_count'] === 0, 'Real auto dataset should have 0 blocking errors');
    echo "Real kolkata-auto-routes.json vs 1,403-seed report: " . json_encode($resReal['summary']) . "\n";
} else {
    $resSeedSelf = cholo_analyze_upload(array_slice($realAutoSeed, 0, 25), ['auto_routes' => $realAutoSeed], 'auto');
    assert_true($resSeedSelf['success'] === true && $resSeedSelf['summary']['exact_duplicates_count'] === 25, 'Seed self-check should match all 25');
}

echo "ALL PHP JSON IMPORTER TESTS PASSED!\n";
