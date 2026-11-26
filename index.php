<?php
/**
 * CholoKolkata • Root Web Entry Point
 */
$req_path = trim(parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH), '/');

if ($req_path === 'app') {
    $app_file = __DIR__ . '/static/app.html';
    if (file_exists($app_file)) {
        header('Content-Type: text/html; charset=utf-8');
        readfile($app_file);
        exit;
    }
}

$static_candidate = __DIR__ . '/static/' . $req_path;
if ($req_path !== '' && strpos($req_path, '..') === false && is_file($static_candidate)) {
    $ext = strtolower(pathinfo($static_candidate, PATHINFO_EXTENSION));
    $mimes = [
        'png' => 'image/png',
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'svg' => 'image/svg+xml',
        'css' => 'text/css; charset=utf-8',
        'js' => 'application/javascript; charset=utf-8',
        'json' => 'application/json; charset=utf-8',
    ];
    header('Content-Type: ' . ($mimes[$ext] ?? 'application/octet-stream'));
    header('Cache-Control: public, max-age=604800');
    readfile($static_candidate);
    exit;
}

$static_file = __DIR__ . '/static/index.html';
if (file_exists($static_file)) {
    header('Content-Type: text/html; charset=utf-8');
    readfile($static_file);
    exit;
} else {
    echo "<h1>CholoKolkata Server Active</h1><p><a href='/deploy.php?key=cholo2026&run=1'>Run Deployer</a></p>";
}

