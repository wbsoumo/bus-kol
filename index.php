<?php
/**
 * CholoKolkata • Root Web Entry Point
 */
$static_file = __DIR__ . '/static/index.html';
if (file_exists($static_file)) {
    header('Content-Type: text/html; charset=utf-8');
    readfile($static_file);
    exit;
} else {
    echo "<h1>CholoKolkata Server Active</h1><p><a href='/deploy.php?key=cholo2026&run=1'>Run Deployer</a></p>";
}

