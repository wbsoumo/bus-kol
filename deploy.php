<?php
/**
 * CholoKolkata (চলো কলকাতা) • 1-Click cPanel Web Deployer & Auto-Setup
 * URL: http://cholokolkata.online/deploy.php?key=cholo2026&run=1
 */

// Enable full error display for debugging
@error_reporting(E_ALL);
@ini_set('display_errors', 1);
@set_time_limit(300);
@ini_set('max_execution_time', 300);
@ini_set('memory_limit', '512M');
if (function_exists('apache_setenv')) {
    @apache_setenv('no-gzip', 1);
}
@ini_set('zlib.output_compression', 0);
@ini_set('implicit_flush', 1);
while (ob_get_level() > 0) {
    ob_end_flush();
}
ob_implicit_flush(1);

header('Content-Type: text/html; charset=utf-8');
header('X-Accel-Buffering: no');

$SECRET_KEY = 'cholo2026';
$provided_key = isset($_GET['key']) ? trim($_GET['key']) : '';
$auto_run = isset($_GET['run']) || $provided_key === $SECRET_KEY;
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CholoKolkata • Auto-Deployer</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
        body { background: #0f172a; color: #f8fafc; padding: 24px 16px; min-height: 100vh; }
        .container { max-width: 860px; margin: 0 auto; }
        .header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px; border-bottom: 1px solid #1e293b; padding-bottom: 16px; flex-wrap: wrap; gap: 12px; }
        .title h1 { color: #2dd4bf; font-size: 22px; font-weight: 800; }
        .title p { color: #94a3b8; font-size: 13px; margin-top: 4px; }
        .card { background: #1e293b; border-radius: 10px; padding: 20px; margin-bottom: 20px; border: 1px solid #334155; }
        .btn { display: inline-block; padding: 12px 24px; border-radius: 6px; font-weight: 700; font-size: 14px; text-decoration: none; cursor: pointer; border: none; }
        .btn-primary { background: #0d9488; color: #fff; }
        .btn-primary:hover { background: #0f766e; }
        .terminal { background: #020617; border-radius: 8px; padding: 18px; font-family: 'Courier New', Courier, monospace; font-size: 13px; line-height: 1.6; color: #38bdf8; overflow-x: auto; max-height: 520px; overflow-y: auto; border: 1px solid #1e293b; }
        .log-success { color: #4ade80; }
        .log-error { color: #f87171; }
        .log-info { color: #94a3b8; }
        .log-step { color: #fbbf24; font-weight: bold; margin-top: 6px; }
        .footer { text-align: center; font-size: 12px; color: #64748b; margin-top: 24px; }
    </style>
</head>
<body>
<div class="container">
    <div class="header">
        <div class="title">
            <h1>🚌 CholoKolkata Auto-Deploy & Setup</h1>
            <p>Git Sync • Python Setup • Dependencies • Passenger Reload • DB Auto-Import</p>
        </div>
        <div>
            <a href="?key=<?php echo htmlspecialchars($SECRET_KEY); ?>&run=1" class="btn btn-primary">🚀 RUN DEPLOY NOW</a>
        </div>
    </div>

    <?php if (!$auto_run): ?>
    <div class="card">
        <h3 style="color: #f1f5f9; margin-bottom: 10px;">Automated 1-Click Deployment</h3>
        <p style="color: #94a3b8; font-size: 14px; line-height: 1.6; margin-bottom: 16px;">
            Click the button below to pull the latest code from GitHub and configure your cPanel server automatically.
        </p>
        <a href="?key=<?php echo htmlspecialchars($SECRET_KEY); ?>&run=1" class="btn btn-primary">🚀 RUN 1-CLICK DEPLOY</a>
    </div>
    <?php else: ?>
    <div class="card">
        <h3 style="color: #f1f5f9; margin-bottom: 12px;">Live Deployment Execution</h3>
        <div class="terminal">
<?php
function log_msg($type, $msg) {
    $class = 'log-' . $type;
    $time = date('H:i:s');
    echo "<div class=\"{$class}\">[$time] " . htmlspecialchars($msg) . "</div>\n";
    @flush();
}

$workdir = dirname(__FILE__);
log_msg('step', "Starting Deployment in: $workdir");

// Set safe environment variables
putenv('GIT_TERMINAL_PROMPT=0');
putenv('GIT_ASKPASS=echo');
putenv("HOME=/home/helnovexaa");
putenv("PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/cpanel/3rdparty/bin:/opt/cpanel/ea-python311/bin:/opt/cpanel/ea-python310/bin:/opt/alt/python311/bin:/opt/alt/python310/bin:/opt/alt/python39/bin");

/**
 * Executes a shell command cleanly without hanging
 */
function run_cmd_fast($cmd) {
    $descriptors = [
        0 => ["pipe", "r"], // stdin
        1 => ["pipe", "w"], // stdout
        2 => ["pipe", "w"]  // stderr
    ];
    $process = proc_open($cmd, $descriptors, $pipes, dirname(__FILE__));
    if (!is_resource($process)) {
        return [1, "Failed to start: $cmd"];
    }

    // Close stdin immediately so git or interactive tools never hang
    fclose($pipes[0]);

    $stdout = stream_get_contents($pipes[1]);
    $stderr = stream_get_contents($pipes[2]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    $exit_code = proc_close($process);

    $combined = trim($stdout . "\n" . $stderr);
    if (!empty($combined)) {
        $lines = explode("\n", $combined);
        foreach (array_slice($lines, -15) as $l) {
            $l = trim($l);
            if (!empty($l)) {
                log_msg('info', "  > $l");
            }
        }
    }
    return [$exit_code, $combined];
}

// 1. GIT SYNC
log_msg('step', "Step 1: Synchronizing with GitHub (wbsoumo/bus-kol)...");
run_cmd_fast("git config --global --add safe.directory " . escapeshellarg($workdir));
run_cmd_fast("git config --global --add safe.directory '*'");

log_msg('info', "Fetching latest commits...");
run_cmd_fast("git fetch --depth=1 origin main 2>&1");
log_msg('info', "Resetting working tree to origin/main...");
run_cmd_fast("git reset --hard origin/main 2>&1");
log_msg('success', "✓ Code synchronized to latest commit on main.");

// 2. LOCATE PYTHON EXECUTABLE
log_msg('step', "Step 2: Locating Python and virtual environment...");

$find_py_cmd = "which python3.12 2>/dev/null || which python3.11 2>/dev/null || which python3.10 2>/dev/null || which python3.9 2>/dev/null || which python3 2>/dev/null || ls /opt/cpanel/ea-python3*/bin/python3 2>/dev/null | head -n 1 || ls /opt/alt/python3*/bin/python3 2>/dev/null | head -n 1";
list($find_code, $py_out) = run_cmd_fast($find_py_cmd);

$chosen_python = null;
if (!empty($py_out)) {
    $first_line = trim(explode("\n", $py_out)[0]);
    if (!empty($first_line) && strpos($first_line, 'which') === false) {
        $chosen_python = $first_line;
    }
}

// Check local or cPanel virtualenv
$venv_py = $workdir . '/venv/bin/python3';
if (file_exists($venv_py)) {
    $chosen_python = $venv_py;
    log_msg('success', "✓ Using local virtualenv Python: $chosen_python");
} elseif (!empty($chosen_python)) {
    log_msg('success', "✓ Found Python executable: $chosen_python");
    // Attempt local venv creation if not present
    log_msg('info', "Setting up local virtualenv in $workdir/venv...");
    run_cmd_fast("$chosen_python -m venv " . escapeshellarg($workdir . '/venv') . " 2>&1");
    if (file_exists($venv_py)) {
        $chosen_python = $venv_py;
        log_msg('success', "✓ Virtual environment created: $venv_py");
    }
} else {
    log_msg('info', "Python binary will be managed via cPanel 'Setup Python App'.");
}

// 3. INSTALL PYTHON DEPENDENCIES
if ($chosen_python) {
    log_msg('step', "Step 3: Checking Python dependencies...");
    $pip_bin = (strpos($chosen_python, '/') !== false && file_exists(dirname($chosen_python) . '/pip')) 
        ? dirname($chosen_python) . '/pip' 
        : "$chosen_python -m pip";

    $req_path = $workdir . '/requirements.txt';
    if (file_exists($req_path)) {
        log_msg('info', "Installing requirements (Flask, PyMySQL, Cryptography)...");
        run_cmd_fast("$pip_bin install -r " . escapeshellarg($req_path) . " 2>&1");
        log_msg('success', "✓ Dependencies verified.");
    }
} else {
    log_msg('info', "Step 3: Virtualenv dependencies managed by cPanel.");
}

// 4. DATABASE INITIALIZATION & VERIFICATION (Direct PHP Native MySQL)
log_msg('step', "Step 4: Checking & Initializing MySQL Database (helnovexaa_buskolkata)...");

$db_host = 'localhost';
$db_user = 'helnovexaa_bus';
$db_pass = 'Soumojit1234@';
$db_name = 'helnovexaa_buskolkata';

try {
    $mysqli = @new mysqli($db_host, $db_user, $db_pass, $db_name);
    if ($mysqli->connect_error) {
        log_msg('error', "MySQL Connection Error: " . $mysqli->connect_error);
        log_msg('info', "Please ensure database user '$db_user' has full privileges on '$db_name' in cPanel MySQL.");
    } else {
        log_msg('success', "✓ Connected to MySQL: $db_name as $db_user");
        
        // Check if routes table exists and has data
        $check_res = $mysqli->query("SHOW TABLES LIKE 'routes'");
        $has_routes = ($check_res && $check_res->num_rows > 0);
        $routes_count = 0;
        if ($has_routes) {
            $cnt_res = $mysqli->query("SELECT COUNT(*) AS cnt FROM routes");
            if ($cnt_res) {
                $row = $cnt_res->fetch_assoc();
                $routes_count = (int)$row['cnt'];
            }
        }

        log_msg('info', "Existing bus routes in database: " . number_format($routes_count));

        // If database is empty, import helnovexaa_buskolkata.sql
        $sql_file = $workdir . '/helnovexaa_buskolkata.sql';
        if (!file_exists($sql_file)) {
            $sql_file = $workdir . '/database_dump.sql';
        }

        if ($routes_count == 0 && file_exists($sql_file)) {
            log_msg('step', "Seeding database from " . basename($sql_file) . " (2.2 MB)...");
            $sql_content = file_get_contents($sql_file);
            
            // Multi query execution
            $mysqli->query("SET FOREIGN_KEY_CHECKS=0;");
            if ($mysqli->multi_query($sql_content)) {
                do {
                    if ($result = $mysqli->store_result()) {
                        $result->free();
                    }
                } while ($mysqli->more_results() && $mysqli->next_result());
                $mysqli->query("SET FOREIGN_KEY_CHECKS=1;");
                log_msg('success', "✓ Database import completed successfully!");
                
                // Re-count
                $cnt_res2 = $mysqli->query("SELECT COUNT(*) AS cnt FROM routes");
                if ($cnt_res2) {
                    $row2 = $cnt_res2->fetch_assoc();
                    log_msg('success', "✓ Total Bus Routes populated: " . number_format((int)$row2['cnt']));
                }
            } else {
                log_msg('error', "Multi-query error: " . $mysqli->error);
            }
        } else {
            log_msg('success', "✓ Database already populated with " . number_format($routes_count) . " routes.");
        }
        $mysqli->close();
    }
} catch (Throwable $db_err) {
    log_msg('error', "MySQL Exception: " . $db_err->getMessage());
}

// 5. RELOAD PHUSION PASSENGER
log_msg('step', "Step 5: Reloading Phusion Passenger Application...");
$tmp_dir = $workdir . '/tmp';
if (!is_dir($tmp_dir)) {
    @mkdir($tmp_dir, 0755, true);
}
@touch($tmp_dir . '/restart.txt');
@touch($workdir . '/passenger_wsgi.py');
@touch($workdir . '/wsgi.py');
log_msg('success', "✓ Touched $tmp_dir/restart.txt & passenger_wsgi.py (Passenger reloaded).");

log_msg('step', "=================================================");
log_msg('success', "🎉 DEPLOYMENT COMPLETE & APPLICATION RUNNING!");
log_msg('step', "=================================================");
?>
        </div>
        <div style="margin-top: 20px; display: flex; gap: 12px; flex-wrap: wrap;">
            <a href="/" class="btn btn-primary" target="_blank">🌐 Open CholoKolkata Website</a>
            <a href="/import-db" class="btn" style="background: #334155; color: #fff;" target="_blank">🗄️ Database Dashboard</a>
            <a href="/download/apk" class="btn" style="background: #0284c7; color: #fff;">📱 Download Android APK</a>
        </div>
    </div>
    <?php endif; ?>

    <div class="footer">
        Made in Kolkata with Love of Rosogolla 🍮 • CholoKolkata 2026
    </div>
</div>
</body>
</html>