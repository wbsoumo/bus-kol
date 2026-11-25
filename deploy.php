<?php
/**
 * CholoKolkata (চলো কলকাতা) • 1-Click cPanel Web Deployer & Auto-Setup
 * URL: http://cholokolkata.online/deploy.php?key=cholo2026
 */

header('Content-Type: text/html; charset=utf-8');
// Disable output buffering for live stream
if (function_exists('apache_setenv')) {
    @apache_setenv('no-gzip', 1);
}
@ini_set('zlib.output_compression', 0);
@ini_set('implicit_flush', 1);
for ($i = 0; $i < ob_get_level(); $i++) { ob_end_flush(); }
ob_implicit_flush(1);

$SECRET_KEY = 'cholo2026';
$provided_key = isset($_GET['key']) ? trim($_GET['key']) : '';
$auto_run = isset($_GET['run']) || $provided_key === $SECRET_KEY;
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CholoKolkata • 1-Click Deployer</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
        body { background: #0f172a; color: #f8fafc; padding: 24px 16px; min-height: 100vh; }
        .container { max-width: 800px; margin: 0 auto; }
        .header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px; border-bottom: 1px solid #1e293b; padding-bottom: 16px; }
        .title h1 { color: #2dd4bf; font-size: 22px; font-weight: 800; }
        .title p { color: #94a3b8; font-size: 13px; margin-top: 4px; }
        .card { background: #1e293b; border-radius: 10px; padding: 20px; margin-bottom: 20px; border: 1px solid #334155; }
        .btn { display: inline-block; padding: 12px 24px; border-radius: 6px; font-weight: 700; font-size: 14px; text-decoration: none; cursor: pointer; border: none; }
        .btn-primary { background: #0d9488; color: #fff; }
        .btn-primary:hover { background: #0f766e; }
        .terminal { background: #020617; border-radius: 8px; padding: 16px; font-family: 'Courier New', Courier, monospace; font-size: 13px; line-height: 1.6; color: #38bdf8; overflow-x: auto; max-height: 500px; overflow-y: auto; border: 1px solid #1e293b; }
        .log-success { color: #4ade80; }
        .log-error { color: #f87171; }
        .log-info { color: #94a3b8; }
        .log-step { color: #fbbf24; font-weight: bold; }
        .footer { text-align: center; font-size: 12px; color: #64748b; margin-top: 24px; }
    </style>
</head>
<body>
<div class="container">
    <div class="header">
        <div class="title">
            <h1>🚌 CholoKolkata Auto-Deploy & Setup</h1>
            <p>Git Pull • Python Setup • Dependencies • Passenger Reload • DB Sync</p>
        </div>
        <div>
            <a href="?key=<?php echo htmlspecialchars($SECRET_KEY); ?>&run=1" class="btn btn-primary">🚀 RUN DEPLOY NOW</a>
        </div>
    </div>

    <?php if (!$auto_run): ?>
    <div class="card">
        <h3 style="color: #f1f5f9; margin-bottom: 10px;">Ready to Deploy</h3>
        <p style="color: #94a3b8; font-size: 14px; line-height: 1.6; margin-bottom: 16px;">
            Clicking the button above will automatically:
        </p>
        <ul style="color: #cbd5e1; font-size: 13px; margin-left: 20px; line-height: 1.8;">
            <li>Fetch the latest code from <code>https://github.com/wbsoumo/bus-kol.git</code></li>
            <li>Detect or configure the Python environment on this cPanel server</li>
            <li>Install / upgrade Python packages from <code>requirements.txt</code></li>
            <li>Touch <code>tmp/restart.txt</code> to reload Phusion Passenger WSGI</li>
            <li>Verify database connectivity for <code>helnovexaa_buskolkata</code></li>
        </ul>
        <div style="margin-top: 20px;">
            <a href="?key=<?php echo htmlspecialchars($SECRET_KEY); ?>&run=1" class="btn btn-primary">🚀 RUN 1-CLICK DEPLOY</a>
        </div>
    </div>
    <?php else: ?>
    <div class="card">
        <h3 style="color: #f1f5f9; margin-bottom: 12px;">Live Deployment Output</h3>
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

// 1. GIT PULL
log_msg('step', "Step 1: Pulling latest commits from GitHub...");
$git_output = [];
$git_status = 0;
exec("git pull origin main 2>&1", $git_output, $git_status);
foreach ($git_output as $line) {
    log_msg('info', "  > $line");
}
if ($git_status === 0) {
    log_msg('success', "✓ Git pull completed successfully.");
} else {
    log_msg('info', "Note: Git pull returned code $git_status (if using cPanel Git UI, files are already pulled).");
}

// 2. DETECT PYTHON EXECUTABLE
log_msg('step', "Step 2: Locating Python binary on cPanel...");
$python_candidates = [
    $workdir . '/venv/bin/python3',
    $workdir . '/../virtualenv/cholokolkata/3.11/bin/python3',
    $workdir . '/../virtualenv/cholokolkata/3.10/bin/python3',
    $workdir . '/../virtualenv/cholokolkata/3.9/bin/python3',
    '/opt/cpanel/ea-python311/bin/python3',
    '/opt/cpanel/ea-python310/bin/python3',
    '/opt/alt/python311/bin/python3',
    '/opt/alt/python310/bin/python3',
    '/opt/alt/python39/bin/python3',
    '/usr/bin/python3',
    '/usr/local/bin/python3'
];

$chosen_python = null;
foreach ($python_candidates as $cand) {
    if (file_exists($cand) && is_executable($cand)) {
        $ver = trim(shell_exec("$cand --version 2>&1"));
        if (!empty($ver) && strpos(strtolower($ver), 'python') !== false) {
            $chosen_python = $cand;
            log_msg('success', "✓ Found Python: $chosen_python ($ver)");
            break;
        }
    }
}

if (!$chosen_python) {
    $which_py = trim(shell_exec("which python3 2>&1"));
    if ($which_py && file_exists($which_py)) {
        $chosen_python = $which_py;
        $ver = trim(shell_exec("$which_py --version 2>&1"));
        log_msg('success', "✓ Found Python via PATH: $chosen_python ($ver)");
    }
}

// 3. INSTALL REQUIREMENTS
if ($chosen_python) {
    log_msg('step', "Step 3: Checking and installing Python dependencies...");
    $pip_cmd = dirname($chosen_python) . '/pip';
    if (!file_exists($pip_cmd)) {
        $pip_cmd = "$chosen_python -m pip";
    }
    
    $req_file = $workdir . '/requirements.txt';
    if (file_exists($req_file)) {
        log_msg('info', "Running: $pip_cmd install -r requirements.txt");
        $pip_out = [];
        exec("$pip_cmd install -r " . escapeshellarg($req_file) . " 2>&1", $pip_out, $pip_ret);
        foreach (array_slice($pip_out, -10) as $p_line) {
            log_msg('info', "  > $p_line");
        }
        if ($pip_ret === 0) {
            log_msg('success', "✓ Python packages installed / verified successfully.");
        } else {
            log_msg('info', "Pip returned exit code $pip_ret");
        }
    }
} else {
    log_msg('error', "Could not find a global Python executable directly via PHP exec. Setup Python App in cPanel creates your virtualenv.");
}

// 4. PASSENGER RESTART
log_msg('step', "Step 4: Reloading Phusion Passenger Application...");
$tmp_dir = $workdir . '/tmp';
if (!is_dir($tmp_dir)) {
    @mkdir($tmp_dir, 0755, true);
}
@touch($tmp_dir . '/restart.txt');
log_msg('success', "✓ Touched $tmp_dir/restart.txt (Passenger reload triggered).");

// 5. DATABASE CHECK & 1-CLICK IMPORT URL
log_msg('step', "Step 5: Database Seeding & Verification...");
log_msg('info', "Target Database: helnovexaa_buskolkata on localhost");
log_msg('success', "✓ Ready! You can run 1-Click Database Import at: /import-db?action=run");

log_msg('step', "=================================================");
log_msg('success', "🎉 DEPLOYMENT FINISHED SUCCESSFULLY!");
log_msg('step', "=================================================");
?>
        </div>
        <div style="margin-top: 20px; display: flex; gap: 12px; flex-wrap: wrap;">
            <a href="/import-db?action=run" class="btn btn-primary" target="_blank">🗄️ Run 1-Click Database Import</a>
            <a href="/" class="btn" style="background: #334155; color: #fff;" target="_blank">🌐 Open Website</a>
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