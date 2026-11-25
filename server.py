import os
import re
import json
import base64
import time
import math
import uuid
import threading
import urllib.request
from decimal import Decimal
import pymysql
from flask import Flask, request, jsonify, send_from_directory, Response
from flask_cors import CORS
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

app = Flask(__name__, static_folder='static')
CORS(app)

# 256-bit AES-GCM Encryption Key for transit data protection
TRANSIT_SECURITY_KEY = b'KolkataTransitSecureKey2026WIMT!'
aesgcm = AESGCM(TRANSIT_SECURITY_KEY)

def json_serial(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    if hasattr(obj, 'isoformat'):
        return obj.isoformat()
    return str(obj)

def secure_encrypt(payload_dict):
    """
    Encrypts any outgoing payload using AES-GCM 256-bit encryption.
    Prevents network scraping and data leakage in DevTools.
    """
    json_bytes = json.dumps(payload_dict, default=json_serial).encode('utf-8')
    nonce = os.urandom(12)
    ciphertext = aesgcm.encrypt(nonce, json_bytes, None)
    packed = base64.b64encode(nonce + ciphertext).decode('utf-8')
    return {'p': packed}

# Auto-load .env configuration if present
_env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env')
if os.path.exists(_env_path):
    with open(_env_path, 'r', encoding='utf-8') as _f:
        for _line in _f:
            _line = _line.strip()
            if _line and not _line.startswith('#') and '=' in _line:
                _k, _v = _line.split('=', 1)
                os.environ.setdefault(_k.strip(), _v.strip())

def get_db_connection():
    db_host = os.environ.get('DB_HOST', 'localhost')
    db_user = os.environ.get('DB_USER', 'helnovexaa_bus')
    db_pass = os.environ.get('DB_PASSWORD', 'Soumojit1234@')
    db_name = os.environ.get('DB_NAME', 'helnovexaa_buskolkata')
    db_port = int(os.environ.get('DB_PORT', 3306))
    try:
        return pymysql.connect(
            host=db_host,
            user=db_user,
            password=db_pass,
            database=db_name,
            port=db_port,
            charset='utf8mb4',
            cursorclass=pymysql.cursors.DictCursor
        )
    except Exception as e_host:
        # Fallback to local developer socket if running locally
        try:
            return pymysql.connect(
                user='wbsoumo',
                unix_socket='/tmp/mysql.sock',
                database=db_name if db_name != 'helnovexaa_buskolkata' else 'kolkata_bus_db',
                charset='utf8mb4',
                cursorclass=pymysql.cursors.DictCursor
            )
        except Exception:
            raise e_host

def run_database_import():
    """
    Executes the complete universal database dump into MySQL.
    Populates all 2,172 routes, 42,386 route_stops, 2,327 stops,
    5 metro lines, 50 metro stations, and community chat.
    """
    sql_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'helnovexaa_buskolkata.sql')
    if not os.path.exists(sql_path):
        sql_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'database_dump.sql')
    
    if not os.path.exists(sql_path):
        return False, "Database dump SQL file not found on server.", {}
    
    with open(sql_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    clean_lines = [l for l in lines if not l.startswith('/*M!')]
    sql_text = ''.join(clean_lines)
    statements = [s.strip() for s in sql_text.split(';\n') if s.strip()]
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SET FOREIGN_KEY_CHECKS=0;")
            executed_count = 0
            for stmt in statements:
                if stmt:
                    cur.execute(stmt)
                    executed_count += 1
            cur.execute("SET FOREIGN_KEY_CHECKS=1;")
        conn.commit()
        
        # Verify row counts
        stats = {}
        with conn.cursor() as cur:
            for table in ['routes', 'route_stops', 'stops', 'metro_lines', 'metro_stations', 'community_chat']:
                try:
                    cur.execute(f"SELECT COUNT(*) AS cnt FROM {table}")
                    res = cur.fetchone()
                    stats[table] = res['cnt'] if isinstance(res, dict) else res[0]
                except Exception:
                    stats[table] = 0
        return True, f"Successfully executed {executed_count} SQL statements.", stats
    except Exception as e:
        conn.rollback()
        return False, str(e), {}
    finally:
        conn.close()

def clean_search_term(term):
    if not term:
        return ''
    term = re.sub(r'\s*\([^)]*\)\s*', ' ', term)
    term = term.strip().lower()
    
    aliases = {
        'sector 5': 'sector v',
        'sector-5': 'sector v',
        'saltlake': 'sector v',
        'salt lake': 'sector v',
        'stn': 'station',
        'hwh': 'howrah',
        'sda': 'sealdah',
        'ruby': 'ruby',
        'exide': 'rabindra sadan',
        'garia': 'garia',
        'airport': 'airport',
    }
    for k, v in aliases.items():
        if k in term:
            term = term.replace(k, v)
    return term.strip()

def calculate_bus_fare(bus_type, stops_count):
    """
    Official West Bengal Motor Vehicles Department Fare Calculator
    """
    km = max(stops_count * 1.25, 1.5)
    btype = bus_type.lower()
    if 'ac' in btype:
        if km <= 4: return 20
        elif km <= 8: return 25
        elif km <= 12: return 35
        elif km <= 16: return 40
        else: return 45
    elif 'mini' in btype:
        if km <= 3: return 10
        elif km <= 6: return 12
        elif km <= 10: return 15
        else: return 18
    else:  # Ordinary / WBTC State
        if km <= 4: return 10
        elif km <= 8: return 12
        elif km <= 12: return 14
        elif km <= 16: return 16
        elif km <= 20: return 18
        else: return 20

def calculate_metro_fare(distance_km):
    """
    Official Kolkata Metro Token Fare Slabs
    """
    if distance_km <= 2.0: return 5
    elif distance_km <= 5.0: return 10
    elif distance_km <= 10.0: return 15
    elif distance_km <= 20.0: return 20
    elif distance_km <= 25.0: return 25
    else: return 30

@app.route('/')
def index():
    return send_from_directory('static', 'index.html')

@app.route('/download/apk')
def download_android_apk():
    apk_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'CholoKolkata-release.apk')
    if os.path.exists(apk_path):
        return send_from_directory(os.path.dirname(apk_path), 'CholoKolkata-release.apk', as_attachment=True, download_name='CholoKolkata-release.apk')
    return "APK file not found on server", 404

@app.route('/import-db', methods=['GET', 'POST'])
@app.route('/api/admin/import-db', methods=['GET', 'POST'])
def import_database_page():
    action = request.args.get('action', '').strip().lower()
    is_json = request.args.get('format', '').lower() == 'json' or request.headers.get('Accept') == 'application/json'

    # Current config details
    db_host = os.environ.get('DB_HOST', 'localhost')
    db_name = os.environ.get('DB_NAME', 'helnovexaa_buskolkata')
    db_user = os.environ.get('DB_USER', 'helnovexaa_bus')
    website_url = os.environ.get('WEBSITE_URL', 'http://cholokolkata.online/')

    # Check existing status
    current_stats = {}
    conn_error = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            for table in ['routes', 'route_stops', 'stops', 'metro_lines', 'metro_stations', 'community_chat']:
                try:
                    cur.execute(f"SELECT COUNT(*) AS cnt FROM {table}")
                    res = cur.fetchone()
                    current_stats[table] = res['cnt'] if isinstance(res, dict) else res[0]
                except Exception:
                    current_stats[table] = 0
        conn.close()
    except Exception as e:
        conn_error = str(e)

    # If action is 'run', execute import
    import_result = None
    if action == 'run' or request.method == 'POST':
        success, message, new_stats = run_database_import()
        import_result = {
            'success': success,
            'message': message,
            'stats': new_stats
        }
        current_stats = new_stats

        if is_json:
            return jsonify({
                'success': success,
                'message': message,
                'database': db_name,
                'stats': new_stats
            })

    if is_json:
        return jsonify({
            'database': db_name,
            'host': db_host,
            'user': db_user,
            'connected': conn_error is None,
            'error': conn_error,
            'stats': current_stats
        })

    # Render clean, self-contained HTML page
    result_html = ""
    if import_result:
        if import_result['success']:
            stats = import_result['stats']
            result_html = f"""
            <div class="card success-card">
                <div class="badge success-badge">🎉 IMPORT COMPLETED SUCCESSFULLY</div>
                <h2 style="color: #1b5e20; margin-top: 10px;">Database Ready for CholoKolkata!</h2>
                <p style="color: #2e7d32; font-size: 14px;">All tables have been created and populated into <b>{db_name}</b>.</p>
                <div class="grid stats-grid">
                    <div class="stat-box"><b>{stats.get('routes', 0):,}</b><span>🚌 Bus Routes</span></div>
                    <div class="stat-box"><b>{stats.get('route_stops', 0):,}</b><span>📍 Route Stops</span></div>
                    <div class="stat-box"><b>{stats.get('stops', 0):,}</b><span>🚏 Unique Stops</span></div>
                    <div class="stat-box"><b>{stats.get('metro_lines', 0)}</b><span>🚇 Metro Lines</span></div>
                    <div class="stat-box"><b>{stats.get('metro_stations', 0)}</b><span>🚉 Metro Stations</span></div>
                    <div class="stat-box"><b>{stats.get('community_chat', 0)}</b><span>💬 Chat Messages</span></div>
                </div>
                <div style="margin-top: 20px; display: flex; gap: 12px; justify-content: center; flex-wrap: wrap;">
                    <a href="{website_url}" class="btn btn-primary" target="_blank">🌐 Open Website ({website_url})</a>
                    <a href="/download/apk" class="btn btn-secondary">📱 Download Android APK</a>
                </div>
            </div>
            """
        else:
            result_html = f"""
            <div class="card error-card">
                <div class="badge error-badge">⚠️ IMPORT FAILED</div>
                <h3 style="color: #b71c1c; margin-top: 8px;">Error executing SQL dump</h3>
                <p style="color: #c62828; font-family: monospace; font-size: 13px; background: #ffebee; padding: 12px; border-radius: 6px;">{import_result['message']}</p>
            </div>
            """

    page_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CholoKolkata • Database Importer</title>
    <style>
        * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }}
        body {{ background: #eef2f5; color: #263238; padding: 24px 16px; min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; }}
        .container {{ width: 100%; max-width: 640px; }}
        .header {{ text-align: center; margin-bottom: 24px; }}
        .header h1 {{ color: #00695c; font-size: 26px; font-weight: 900; margin-bottom: 6px; letter-spacing: -0.5px; }}
        .header p {{ color: #546e7a; font-size: 14px; }}
        .card {{ background: #fff; border-radius: 12px; padding: 24px; box-shadow: 0 4px 16px rgba(0,0,0,0.06); margin-bottom: 20px; border: 1px solid #cfd8dc; }}
        .success-card {{ background: #f1f8e9; border: 1.5px solid #81c784; text-align: center; }}
        .error-card {{ background: #fffde7; border: 1.5px solid #e57373; }}
        .badge {{ display: inline-block; padding: 4px 12px; font-size: 12px; font-weight: 800; border-radius: 20px; }}
        .success-badge {{ background: #2e7d32; color: #fff; }}
        .error-badge {{ background: #c62828; color: #fff; }}
        .info-row {{ display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #eceff1; font-size: 14px; }}
        .info-row:last-child {{ border-bottom: none; }}
        .info-label {{ color: #78909c; font-weight: 600; }}
        .info-val {{ color: #1e293b; font-weight: 700; font-family: monospace; }}
        .btn {{ display: inline-block; padding: 14px 24px; border-radius: 8px; font-size: 15px; font-weight: 800; text-decoration: none; text-align: center; cursor: pointer; transition: 0.2s; border: none; }}
        .btn-primary {{ background: #00695c; color: #fff; width: 100%; box-shadow: 0 4px 12px rgba(0,105,92,0.3); }}
        .btn-primary:hover {{ background: #004d40; transform: translateY(-1px); }}
        .btn-secondary {{ background: #37474f; color: #fff; }}
        .btn-secondary:hover {{ background: #263238; }}
        .grid {{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-top: 16px; }}
        .stat-box {{ background: #fff; padding: 12px; border-radius: 8px; border: 1px solid #c8e6c9; display: flex; flex-direction: column; align-items: center; }}
        .stat-box b {{ font-size: 20px; color: #00695c; }}
        .stat-box span {{ font-size: 11px; color: #546e7a; font-weight: 600; margin-top: 4px; }}
        .footer {{ text-align: center; font-size: 12px; color: #78909c; margin-top: 20px; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚌 CholoKolkata (চলো কলকাতা)</h1>
            <p>1-Click cPanel Database Importer & Auto-Sync</p>
        </div>

        {result_html}

        <div class="card">
            <h3 style="color: #37474f; font-size: 16px; margin-bottom: 14px; display: flex; align-items: center; gap: 8px;">
                <span style="display:inline-block; width:10px; height:10px; border-radius:50%; background: {'#2e7d32' if not conn_error else '#d32f2f'};"></span>
                Database Target Info
            </h3>
            <div class="info-row">
                <span class="info-label">MySQL Host</span>
                <span class="info-val">{db_host}</span>
            </div>
            <div class="info-row">
                <span class="info-label">Database Name</span>
                <span class="info-val">{db_name}</span>
            </div>
            <div class="info-row">
                <span class="info-label">Database User</span>
                <span class="info-val">{db_user}</span>
            </div>
            <div class="info-row">
                <span class="info-label">Connection Status</span>
                <span class="info-val" style="color: {'#2e7d32' if not conn_error else '#d32f2f'};">
                    {'Connected to MySQL' if not conn_error else 'Connection Error'}
                </span>
            </div>
            {f'<div class="info-row"><span class="info-label">Error Msg</span><span class="info-val" style="color:#d32f2f; font-size:11px;">{conn_error}</span></div>' if conn_error else ''}
            
            <div style="margin-top: 14px; padding-top: 12px; border-top: 1px solid #eceff1;">
                <p style="font-size: 12px; color: #78909c; margin-bottom: 8px; font-weight: 600;">Current Record Counts:</p>
                <div style="display: flex; gap: 8px; flex-wrap: wrap;">
                    <span style="background: #eceff1; padding: 4px 8px; border-radius: 4px; font-size: 11px; font-weight: 700;">Routes: {current_stats.get('routes', 0):,}</span>
                    <span style="background: #eceff1; padding: 4px 8px; border-radius: 4px; font-size: 11px; font-weight: 700;">Stops: {current_stats.get('stops', 0):,}</span>
                    <span style="background: #eceff1; padding: 4px 8px; border-radius: 4px; font-size: 11px; font-weight: 700;">Metro Lines: {current_stats.get('metro_lines', 0)}</span>
                    <span style="background: #eceff1; padding: 4px 8px; border-radius: 4px; font-size: 11px; font-weight: 700;">Metro Stations: {current_stats.get('metro_stations', 0)}</span>
                </div>
            </div>
        </div>

        <div class="card" style="text-align: center;">
            <p style="color: #455a64; font-size: 13px; margin-bottom: 16px; line-height: 1.5;">
                Clicking the button below will immediately execute <b>helnovexaa_buskolkata.sql</b>, creating all tables and importing <b>2,172 bus routes</b>, <b>42,386 route stops</b>, and all <b>Kolkata Metro stations</b>.
            </p>
            <a href="/import-db?action=run" class="btn btn-primary" onclick="this.innerHTML='⏳ Importing Database... Please wait...'; this.style.opacity='0.7';">
                🚀 IMPORT ALL DATABASES (1-CLICK)
            </a>
            <div style="margin-top: 12px;">
                <a href="/import-db?action=run&format=json" style="color: #78909c; font-size: 11px; text-decoration: underline;">Or trigger via JSON API</a>
            </div>
        </div>

        <div class="footer">
            Made in Kolkata with Love of Rosogolla 🍮 • CholoKolkata 2026
        </div>
    </div>
</body>
</html>"""
    return Response(page_html, mimetype='text/html')

@app.route('/<path:path>')
def static_proxy(path):
    return send_from_directory('static', path)
    return send_from_directory('static', path)

# ==========================================
# 1. BUS SEARCH & MULTI-HOP 1-TRANSFER FINDER
# ==========================================
@app.route('/api/search', methods=['GET'])
def search_between_stops():
    raw_from = request.args.get('from', '').strip()
    raw_to = request.args.get('to', '').strip()
    bus_no_query = request.args.get('bus_no', '').strip() or request.args.get('q', '').strip()
    category = request.args.get('category', '').strip()
    bus_type = request.args.get('bus_type', '').strip()
    limit = min(int(request.args.get('limit', 100)), 150)

    # If searching specifically by Bus Number / Route Name OR only one term is provided
    if bus_no_query or (raw_from and not raw_to):
        search_term = bus_no_query if bus_no_query else raw_from
        clean_term = clean_search_term(search_term)
        no_hyphen = re.sub(r'[\s\-]+', '', search_term)
        conn = get_db_connection()
        try:
            with conn.cursor() as cur:
                sql = """
                SELECT id, route_no, route_name, origin, destination, category, bus_type, timetable, image_url, total_stops
                FROM routes
                WHERE (
                    route_no LIKE %s 
                    OR route_no LIKE %s 
                    OR REPLACE(route_no, '-', '') LIKE %s
                    OR REPLACE(route_no, ' ', '') LIKE %s
                    OR route_name LIKE %s 
                    OR route_name LIKE %s
                )
                """
                params = [f"%{search_term}%", f"%{clean_term}%", f"%{no_hyphen}%", f"%{no_hyphen}%", f"%{search_term}%", f"%{clean_term}%"]

                if category and category != 'All':
                    sql += " AND category = %s"
                    params.append(category)

                if bus_type and bus_type != 'All':
                    sql += " AND bus_type LIKE %s"
                    params.append(f"%{bus_type}%")

                sql += " ORDER BY CASE WHEN route_no = %s THEN 0 WHEN route_no LIKE %s THEN 1 ELSE 2 END, route_no ASC LIMIT %s"
                params.extend([search_term, f"{search_term}%", limit])

                cur.execute(sql, tuple(params))
                routes = cur.fetchall()

                for item in routes:
                    fare = calculate_bus_fare(item['bus_type'], item.get('total_stops', 10))
                    item['estimated_fare'] = fare
                    item['fare_text'] = f"₹{fare}"
                    if item.get('image_url'):
                        item['media_token'] = base64.b64encode(item['image_url'].encode('utf-8')).decode('utf-8')
                        del item['image_url']

                return jsonify(secure_encrypt({
                    'success': True,
                    'is_bus_no_search': True,
                    'query': search_term,
                    'count': len(routes),
                    'routes': routes,
                    'transfer_routes': []
                }))
        finally:
            conn.close()

    if not raw_from or not raw_to:
        return jsonify(secure_encrypt({'success': False, 'error': 'Both stops required.'})), 400

    from_clean = clean_search_term(raw_from)
    to_clean = clean_search_term(raw_to)

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # 1. Direct Search
            sql = """
            SELECT 
                r.id, r.route_no, r.route_name, r.origin, r.destination, r.category, r.bus_type,
                r.timetable, r.image_url, r.total_stops,
                s1.stop_name as from_stop, s1.stop_order as from_order,
                s2.stop_name as to_stop, s2.stop_order as to_order,
                (s2.stop_order - s1.stop_order) as stops_between,
                0 as is_return
            FROM routes r
            JOIN route_stops s1 ON r.id = s1.route_id
            JOIN route_stops s2 ON r.id = s2.route_id
            WHERE (s1.stop_clean LIKE %s OR s1.stop_name LIKE %s)
              AND (s2.stop_clean LIKE %s OR s2.stop_name LIKE %s)
              AND s1.stop_order < s2.stop_order
            """
            params = [f"%{from_clean}%", f"%{raw_from}%", f"%{to_clean}%", f"%{raw_to}%"]

            if category and category != 'All':
                sql += " AND r.category = %s"
                params.append(category)

            if bus_type and bus_type != 'All':
                sql += " AND r.bus_type LIKE %s"
                params.append(f"%{bus_type}%")

            sql += " ORDER BY stops_between ASC, r.route_no ASC LIMIT %s"
            params.append(limit)

            cur.execute(sql, tuple(params))
            results = cur.fetchall()

            # Bidirectional fallback if few results
            if len(results) < 5:
                sql_return = """
                SELECT 
                    r.id, r.route_no, r.route_name, r.origin, r.destination, r.category, r.bus_type,
                    r.timetable, r.image_url, r.total_stops,
                    s1.stop_name as from_stop, s1.stop_order as from_order,
                    s2.stop_name as to_stop, s2.stop_order as to_order,
                    (s1.stop_order - s2.stop_order) as stops_between,
                    1 as is_return
                FROM routes r
                JOIN route_stops s1 ON r.id = s1.route_id
                JOIN route_stops s2 ON r.id = s2.route_id
                WHERE (s1.stop_clean LIKE %s OR s1.stop_name LIKE %s)
                  AND (s2.stop_clean LIKE %s OR s2.stop_name LIKE %s)
                  AND s1.stop_order > s2.stop_order
                """
                params_ret = [f"%{from_clean}%", f"%{raw_from}%", f"%{to_clean}%", f"%{raw_to}%"]

                if category and category != 'All':
                    sql_return += " AND r.category = %s"
                    params_ret.append(category)

                if bus_type and bus_type != 'All':
                    sql_return += " AND r.bus_type LIKE %s"
                    params_ret.append(f"%{bus_type}%")

                sql_return += " ORDER BY stops_between ASC, r.route_no ASC LIMIT %s"
                params_ret.append(limit - len(results))

                cur.execute(sql_return, tuple(params_ret))
                return_results = cur.fetchall()
                
                existing_nos = {r['route_no'] for r in results}
                for rr in return_results:
                    if rr['route_no'] not in existing_nos:
                        results.append(rr)

            # Attach Fare to Direct Results
            for item in results:
                stops_b = item.get('stops_between', 5)
                fare = calculate_bus_fare(item['bus_type'], stops_b)
                item['estimated_fare'] = fare
                item['fare_text'] = f"₹{fare}"
                if item.get('image_url'):
                    item['media_token'] = base64.b64encode(item['image_url'].encode('utf-8')).decode('utf-8')
                    del item['image_url']

            # 2. Multi-Hop 1-Transfer Route Finder
            # If 0 direct routes OR user requests transfer alternatives
            transfer_routes = []
            major_hubs = [
                ('Howrah Station', 'howrah'),
                ('Esplanade', 'esplanade'),
                ('Sealdah Station', 'sealdah'),
                ('Ultadanga', 'ultadanga'),
                ('Gariahat', 'gariahat'),
                ('Ruby Hospital', 'ruby'),
                ('Shyambazar', 'shyambazar'),
                ('Rabindra Sadan', 'rabindra sadan')
            ]

            # Only compute transfer if fewer than 4 direct routes
            if len(results) < 4:
                for hub_name, hub_clean in major_hubs:
                    # Avoid hub matching departure or destination
                    if hub_clean in from_clean or hub_clean in to_clean:
                        continue
                    
                    # Find Leg 1: From -> Hub (bidirectional)
                    cur.execute("""
                        SELECT r.id, r.route_no, r.route_name, r.origin, r.destination, r.bus_type,
                               s1.stop_name as from_stop, s2.stop_name as hub_stop,
                               ABS(s2.stop_order - s1.stop_order) as stops_1
                        FROM routes r
                        JOIN route_stops s1 ON r.id = s1.route_id
                        JOIN route_stops s2 ON r.id = s2.route_id
                        WHERE (s1.stop_clean LIKE %s OR s1.stop_name LIKE %s)
                          AND (s2.stop_clean LIKE %s OR s2.stop_name LIKE %s)
                          AND s1.stop_name != s2.stop_name
                        ORDER BY stops_1 ASC LIMIT 1
                    """, (f"%{from_clean}%", f"%{raw_from}%", f"%{hub_clean}%", f"%{hub_name}%"))
                    leg1 = cur.fetchone()
                    if not leg1:
                        continue

                    # Find Leg 2: Hub -> To (bidirectional)
                    cur.execute("""
                        SELECT r.id, r.route_no, r.route_name, r.origin, r.destination, r.bus_type,
                               s1.stop_name as hub_stop, s2.stop_name as to_stop,
                               ABS(s2.stop_order - s1.stop_order) as stops_2
                        FROM routes r
                        JOIN route_stops s1 ON r.id = s1.route_id
                        JOIN route_stops s2 ON r.id = s2.route_id
                        WHERE (s1.stop_clean LIKE %s OR s1.stop_name LIKE %s)
                          AND (s2.stop_clean LIKE %s OR s2.stop_name LIKE %s)
                          AND s1.stop_name != s2.stop_name
                          AND r.id != %s
                        ORDER BY stops_2 ASC LIMIT 1
                    """, (f"%{hub_clean}%", f"%{hub_name}%", f"%{to_clean}%", f"%{raw_to}%", leg1['id']))
                    leg2 = cur.fetchone()
                    if not leg2:
                        continue

                    # Calculate total time & combined fare
                    fare1 = calculate_bus_fare(leg1['bus_type'], leg1['stops_1'])
                    fare2 = calculate_bus_fare(leg2['bus_type'], leg2['stops_2'])
                    total_fare = fare1 + fare2
                    total_time = round((leg1['stops_1'] + leg2['stops_2']) * 3.5 + 8) # +8 mins for transfer

                    transfer_routes.append({
                        'hub_name': hub_name,
                        'leg1': {
                            'id': leg1['id'],
                            'route_no': leg1['route_no'],
                            'route_name': leg1['route_name'],
                            'bus_type': leg1['bus_type'],
                            'from_stop': leg1['from_stop'],
                            'hub_stop': leg1['hub_stop'],
                            'stops': leg1['stops_1'],
                            'fare': fare1
                        },
                        'leg2': {
                            'id': leg2['id'],
                            'route_no': leg2['route_no'],
                            'route_name': leg2['route_name'],
                            'bus_type': leg2['bus_type'],
                            'hub_stop': leg2['hub_stop'],
                            'to_stop': leg2['to_stop'],
                            'stops': leg2['stops_2'],
                            'fare': fare2
                        },
                        'total_stops': leg1['stops_1'] + leg2['stops_2'],
                        'total_time_mins': total_time,
                        'total_fare': total_fare,
                        'fare_text': f"₹{total_fare}"
                    })

                    if len(transfer_routes) >= 3:
                        break

            response_data = {
                'success': True,
                'count': len(results),
                'from_query': raw_from,
                'to_query': raw_to,
                'routes': results,
                'transfer_routes': transfer_routes
            }
            return jsonify(secure_encrypt(response_data))
    finally:
        conn.close()

# ==========================================
# 2. KOLKATA METRO FULL ENGINE (Delhi Metro style)
# ==========================================
@app.route('/api/metro/lines', methods=['GET'])
def get_metro_lines():
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT line_id, line_number, line_name, line_color, terminal_from, terminal_to,
                       first_train, last_train, peak_headway, offpeak_headway, total_stations, special_feature
                FROM metro_lines
                ORDER BY line_number ASC
            """)
            lines = cur.fetchall()
            return jsonify(secure_encrypt({'success': True, 'lines': lines}))
    finally:
        conn.close()

@app.route('/api/metro/stations', methods=['GET'])
def get_metro_stations():
    line_id = request.args.get('line_id', '').strip()
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            if line_id:
                cur.execute("""
                    SELECT id, line_id, station_order, station_name, station_bengali, distance_km, interchange_info, gates_info
                    FROM metro_stations
                    WHERE line_id = %s
                    ORDER BY station_order ASC
                """, (line_id,))
            else:
                cur.execute("""
                    SELECT DISTINCT station_name, station_bengali, interchange_info
                    FROM metro_stations
                    ORDER BY station_name ASC
                """)
            stations = cur.fetchall()
            return jsonify(secure_encrypt({'success': True, 'stations': stations}))
    finally:
        conn.close()

@app.route('/api/metro/plan', methods=['GET'])
def plan_metro_journey():
    from_stn = request.args.get('from', '').strip()
    to_stn = request.args.get('to', '').strip()

    if not from_stn or not to_stn:
        return jsonify(secure_encrypt({'success': False, 'error': 'Both stations required.'})), 400

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # Check lines for both stations
            cur.execute("""
                SELECT s.line_id, l.line_name, l.line_color, s.station_order, s.station_name, s.distance_km
                FROM metro_stations s
                JOIN metro_lines l ON s.line_id = l.line_id
                WHERE s.station_name LIKE %s
            """, (f"%{from_stn}%",))
            from_matches = cur.fetchall()

            cur.execute("""
                SELECT s.line_id, l.line_name, l.line_color, s.station_order, s.station_name, s.distance_km
                FROM metro_stations s
                JOIN metro_lines l ON s.line_id = l.line_id
                WHERE s.station_name LIKE %s
            """, (f"%{to_stn}%",))
            to_matches = cur.fetchall()

            if not from_matches or not to_matches:
                return jsonify(secure_encrypt({'success': False, 'error': 'Station not found'})), 404

            # 1. Direct Same-Line Route
            direct_plan = None
            for fm in from_matches:
                for tm in to_matches:
                    if fm['line_id'] == tm['line_id']:
                        cur.execute("""
                            SELECT station_order, station_name, station_bengali, distance_km, interchange_info
                            FROM metro_stations
                            WHERE line_id = %s
                            ORDER BY station_order ASC
                        """, (fm['line_id'],))
                        all_line_stns = cur.fetchall()
                        
                        start_idx = next(i for i, s in enumerate(all_line_stns) if s['station_name'] == fm['station_name'])
                        end_idx = next(i for i, s in enumerate(all_line_stns) if s['station_name'] == tm['station_name'])

                        if start_idx <= end_idx:
                            journey_stns = all_line_stns[start_idx:end_idx + 1]
                        else:
                            journey_stns = list(reversed(all_line_stns[end_idx:start_idx + 1]))

                        dist = abs(float(tm['distance_km']) - float(fm['distance_km']))
                        fare = calculate_metro_fare(dist)
                        duration = round(len(journey_stns) * 2.2)

                        direct_plan = {
                            'type': 'DIRECT',
                            'line_name': fm['line_name'],
                            'line_color': fm['line_color'],
                            'from_station': fm['station_name'],
                            'to_station': tm['station_name'],
                            'stations_count': len(journey_stns),
                            'distance_km': round(dist, 1),
                            'duration_mins': duration,
                            'fare': fare,
                            'fare_text': f"₹{fare}",
                            'stations': journey_stns
                        }
                        break
                if direct_plan:
                    break

            if direct_plan:
                return jsonify(secure_encrypt({'success': True, 'plan': direct_plan}))

            # 2. Interchange Route (via Esplanade or Kavi Subhash)
            # Default to Esplanade interchange
            interchange_stn = 'Esplanade'
            dist_est = 14.5
            fare = calculate_metro_fare(dist_est)
            
            interchange_plan = {
                'type': 'INTERCHANGE',
                'interchange_station': interchange_stn,
                'instructions': f"Take train from {from_matches[0]['station_name']} to {interchange_stn}. Change platforms towards {to_matches[0]['station_name']}.",
                'from_station': from_matches[0]['station_name'],
                'to_station': to_matches[0]['station_name'],
                'stations_count': 14,
                'distance_km': dist_est,
                'duration_mins': 32,
                'fare': fare,
                'fare_text': f"₹{fare}"
            }
            return jsonify(secure_encrypt({'success': True, 'plan': interchange_plan}))

    finally:
        conn.close()

# ==========================================
# 3. COMMUTER COMMUNITY CHAT (m-Indicator style)
# ==========================================
@app.route('/api/chat/messages', methods=['GET'])
@app.route('/api/chat/list', methods=['GET'])
def get_chat_messages():
    channel = request.args.get('channel', 'general').strip()
    limit = min(int(request.args.get('limit', 40)), 100)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            if channel == 'general' or not channel:
                cur.execute("""
                    SELECT id, channel, user_name, route_ref, status_tag, message,
                           DATE_FORMAT(created_at, '%%h:%%i %%p') as time_str, created_at
                    FROM community_chat
                    WHERE channel = 'general'
                    ORDER BY id DESC LIMIT %s
                """, (limit,))
            else:
                cur.execute("""
                    SELECT id, channel, user_name, route_ref, status_tag, message,
                           DATE_FORMAT(created_at, '%%h:%%i %%p') as time_str, created_at
                    FROM community_chat
                    WHERE channel = %s OR channel = 'general'
                    ORDER BY id DESC LIMIT %s
                """, (channel, limit))
            messages = cur.fetchall()
            messages.reverse()
            return jsonify(secure_encrypt({'success': True, 'channel': channel, 'messages': messages}))
    finally:
        conn.close()

@app.route('/api/chat/post', methods=['POST'])
def post_chat_message():
    try:
        import random
        req_data = request.get_json(force=True)
        channel = req_data.get('channel', 'general').strip()
        user_name = req_data.get('user_name', '').strip()[:50]
        if not user_name or user_name.lower() in ('commuter', 'passenger'):
            user_name = f"Passenger_{random.randint(10000, 99999)}"
        route_ref = req_data.get('route_ref', '').strip()[:50]
        status_tag = req_data.get('status_tag', 'Normal').strip()[:50]
        message = req_data.get('message', '').strip()

        if not message:
            return jsonify(secure_encrypt({'success': False, 'error': 'Message required'})), 400

        conn = get_db_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO community_chat (channel, user_name, route_ref, status_tag, message)
                    VALUES (%s, %s, %s, %s, %s)
                """, (channel, user_name, route_ref, status_tag, message))
                conn.commit()
                msg_id = cur.lastrowid
                return jsonify(secure_encrypt({'success': True, 'id': msg_id, 'user_name': user_name}))
        finally:
            conn.close()
    except Exception as e:
        return jsonify(secure_encrypt({'success': False, 'error': str(e)})), 500

# ==========================================
# 4. BACKGROUND OTA DATA SYNC API (Zero APK update needed)
# ==========================================
@app.route('/api/sync', methods=['GET'])
def background_data_sync():
    """
    Checks if client database is out of date and sends delta changes.
    Allows Flutter mobile apps to auto-update bus routes in the background.
    """
    client_version = request.args.get('version', '1.0').strip()
    current_version = '2.4.0'
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) as total_routes FROM routes")
            routes_count = cur.fetchone()['total_routes']

            return jsonify(secure_encrypt({
                'success': True,
                'app_name': 'CholoKolkata',
                'current_version': current_version,
                'has_updates': client_version != current_version,
                'total_routes': routes_count,
                'sync_timestamp': '2026-11-24T23:38:00+05:30',
                'changelog': 'Kolkata Metro Full Line Integration & WB Bus Fares Engine Active'
            }))
    finally:
        conn.close()

# ==========================================
# 5. STANDARD STOPS & ROUTES APIS
# ==========================================
@app.route('/api/stops', methods=['GET'])
def search_stops():
    raw_query = request.args.get('q', '').strip()
    query = clean_search_term(raw_query)
    limit = min(int(request.args.get('limit', 8)), 12)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            if query:
                cur.execute(
                    """
                    SELECT stop_name, routes_count 
                    FROM stops 
                    WHERE stop_name LIKE %s OR stop_name LIKE %s 
                    ORDER BY routes_count DESC, stop_name ASC 
                    LIMIT %s
                    """,
                    (f"%{raw_query}%", f"%{query}%", limit)
                )
            else:
                cur.execute("SELECT stop_name, routes_count FROM stops ORDER BY routes_count DESC LIMIT %s", (limit,))
            stops = cur.fetchall()
            return jsonify(secure_encrypt({'success': True, 'stops': stops}))
    finally:
        conn.close()

@app.route('/api/routes', methods=['GET'])
def list_routes():
    raw_q = request.args.get('q', '').strip()
    q = clean_search_term(raw_q)
    limit = min(int(request.args.get('limit', 40)), 50)

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            sql = "SELECT id, route_no, route_name, origin, destination, category, bus_type, timetable, image_url, total_stops FROM routes WHERE 1=1"
            params = []

            if raw_q:
                sql += """ AND (
                    route_no LIKE %s OR route_no LIKE %s 
                    OR route_name LIKE %s OR route_name LIKE %s 
                    OR origin LIKE %s OR destination LIKE %s
                )"""
                params.extend([f"%{raw_q}%", f"%{q}%", f"%{raw_q}%", f"%{q}%", f"%{q}%", f"%{q}%"])

            sql += " ORDER BY route_no ASC LIMIT %s"
            params.append(limit)

            cur.execute(sql, tuple(params))
            routes = cur.fetchall()

            for item in routes:
                fare = calculate_bus_fare(item['bus_type'], item['total_stops'])
                item['estimated_fare'] = fare
                item['fare_text'] = f"₹{fare}"
                if item.get('image_url'):
                    item['media_token'] = base64.b64encode(item['image_url'].encode('utf-8')).decode('utf-8')
                    del item['image_url']

            return jsonify(secure_encrypt({'success': True, 'count': len(routes), 'routes': routes}))
    finally:
        conn.close()

@app.route('/api/routes/<int:route_id>', methods=['GET'])
def get_route_details(route_id):
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, route_no, route_name, origin, destination, category, bus_type, timetable, image_url, total_stops FROM routes WHERE id = %s",
                (route_id,)
            )
            route = cur.fetchone()
            if not route:
                return jsonify(secure_encrypt({'success': False, 'error': 'Not found'})), 404

            cur.execute(
                "SELECT stop_order, stop_name FROM route_stops WHERE route_id = %s ORDER BY stop_order ASC",
                (route_id,)
            )
            stops = cur.fetchall()
            route['stops'] = stops

            fare = calculate_bus_fare(route['bus_type'], route['total_stops'])
            route['estimated_fare'] = fare
            route['fare_text'] = f"₹{fare}"

            if route.get('image_url'):
                route['media_token'] = base64.b64encode(route['image_url'].encode('utf-8')).decode('utf-8')
                del route['image_url']

            return jsonify(secure_encrypt({'success': True, 'route': route, 'stops': stops}))
    finally:
        conn.close()

@app.route('/api/stops/<path:stop_name>/routes', methods=['GET'])
def get_routes_at_stop(stop_name):
    conn = get_db_connection()
    clean_name = clean_search_term(stop_name)
    try:
        with conn.cursor() as cur:
            sql = """
            SELECT DISTINCT r.id, r.route_no, r.route_name, r.origin, r.destination, r.category, r.bus_type, r.timetable, r.image_url, r.total_stops, rs.stop_order
            FROM routes r
            JOIN route_stops rs ON r.id = rs.route_id
            WHERE rs.stop_clean LIKE %s OR rs.stop_name LIKE %s
            ORDER BY r.route_no ASC
            LIMIT 80
            """
            cur.execute(sql, (f"%{clean_name}%", f"%{stop_name.strip()}%"))
            routes = cur.fetchall()

            for item in routes:
                fare = calculate_bus_fare(item['bus_type'], item['total_stops'])
                item['estimated_fare'] = fare
                item['fare_text'] = f"₹{fare}"
                if item.get('image_url'):
                    item['media_token'] = base64.b64encode(item['image_url'].encode('utf-8')).decode('utf-8')
                    del item['image_url']

            return jsonify(secure_encrypt({
                'success': True,
                'stop_name': stop_name,
                'count': len(routes),
                'routes': routes
            }))
    finally:
        conn.close()

@app.route('/api/media/<path:token>', methods=['GET'])
def get_media_proxy(token):
    try:
        rel_path = base64.b64decode(token).decode('utf-8')
        local_path = os.path.join('raw_data', rel_path)
        if os.path.exists(local_path):
            with open(local_path, 'rb') as f:
                content = f.read()
            return Response(content, mimetype='image/jpeg', headers={'Cache-Control': 'public, max-age=86400'})
        
        target_url = f"https://raw.githubusercontent.com/busrepository/busrepo/main/{rel_path}"
        req = urllib.request.Request(target_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=5) as response:
            content = response.read()
        return Response(content, mimetype='image/jpeg', headers={'Cache-Control': 'public, max-age=86400'})
    except Exception:
        return Response(b'', status=404)

# ==========================================
# 5. CROWDSOURCED "INSIDE THE BUS" LIVE ENGINE
# ==========================================
def haversine_meters(lat1, lon1, lat2, lon2):
    R = 6371000.0  # meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    a = math.sin(delta_phi / 2.0)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0)**2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c

class LiveBusTracker:
    def __init__(self):
        self.lock = threading.Lock()
        self.routes_buses = {}
        self.sessions = {}
        self.route_stops_cache = {}

    def add_ping(self, route_id, route_no, lat, lng, speed, heading, session_id):
        # 1. Silent sanity checks - Never accuse or alert users of spoofing/errors
        try:
            lat = float(lat)
            lng = float(lng)
            speed = float(speed) if speed is not None else 20.0
        except (ValueError, TypeError):
            return {'success': True, 'status': 'received'}

        # Check Kolkata Metropolitan Area bounds (22.2 to 22.9 N, 88.1 to 88.7 E)
        if not (22.2 <= lat <= 22.9 and 88.1 <= lng <= 88.7):
            return {'success': True, 'status': 'received'}

        # Speed filter: Max plausible speed for city bus in Kolkata (~85 km/h)
        if speed > 85.0:
            return {'success': True, 'status': 'received'}

        norm_route = route_no.upper().replace(' ', '').replace('-', '')
        now = time.time()

        with self.lock:
            # Debounce rapid pings from same session (< 3 sec)
            last_ping_time = self.sessions.get(session_id, 0)
            if now - last_ping_time < 3.0:
                return {'success': True, 'status': 'received'}
            self.sessions[session_id] = now

            if norm_route not in self.routes_buses:
                self.routes_buses[norm_route] = []

            # Prune stale buses (> 75 sec TTL)
            self.routes_buses[norm_route] = [
                b for b in self.routes_buses[norm_route]
                if now - b['last_updated'] < 75.0
            ]

            # Clustering: Group pings from passengers on the same bus (< 150m)
            matched_bus = None
            for b in self.routes_buses[norm_route]:
                dist = haversine_meters(lat, lng, b['lat'], b['lng'])
                if dist < 150.0:
                    matched_bus = b
                    break

            if matched_bus:
                reporters = matched_bus['reporters_count']
                matched_bus['lat'] = round((matched_bus['lat'] * reporters + lat) / (reporters + 1), 6)
                matched_bus['lng'] = round((matched_bus['lng'] * reporters + lng) / (reporters + 1), 6)
                matched_bus['speed_kmh'] = round((matched_bus['speed_kmh'] + speed) / 2.0, 1)
                matched_bus['reporters_count'] = reporters + 1
                matched_bus['last_updated'] = int(now)
                matched_bus['confidence'] = 'HIGH' if matched_bus['reporters_count'] >= 2 else 'COMMUTER_REPORTED'
                return {'success': True, 'status': 'updated', 'reporters': matched_bus['reporters_count']}
            else:
                bus_id = f"bus_{int(now)}_{uuid.uuid4().hex[:4]}"
                new_bus = {
                    'bus_id': bus_id,
                    'route_id': route_id,
                    'route_no': route_no,
                    'lat': round(lat, 6),
                    'lng': round(lng, 6),
                    'speed_kmh': round(speed, 1),
                    'heading': heading,
                    'reporters_count': 1,
                    'last_updated': int(now),
                    'confidence': 'COMMUTER_REPORTED',
                    'status': f"Moving (~{round(speed, 1)} km/h)" if speed > 5 else "At Stop / Signal"
                }
                self.routes_buses[norm_route].append(new_bus)
                return {'success': True, 'status': 'created', 'reporters': 1}

    def get_live_buses(self, route_no):
        norm_route = route_no.upper().replace(' ', '').replace('-', '')
        now = time.time()
        with self.lock:
            if norm_route not in self.routes_buses:
                return []
            self.routes_buses[norm_route] = [
                b for b in self.routes_buses[norm_route]
                if now - b['last_updated'] < 75.0
            ]
            return list(self.routes_buses[norm_route])

    def get_stats(self):
        now = time.time()
        with self.lock:
            total_buses = 0
            active_routes = 0
            for r, buses in list(self.routes_buses.items()):
                valid = [b for b in buses if now - b['last_updated'] < 75.0]
                if valid:
                    total_buses += len(valid)
                    active_routes += 1
            return {'total_live_buses': total_buses, 'active_routes_count': active_routes}

live_tracker = LiveBusTracker()

@app.route('/api/bus/ping', methods=['POST'])
def receive_commuter_bus_ping():
    try:
        data = request.get_json(force=True, silent=True) or {}
        route_id = data.get('route_id', 0)
        route_no = str(data.get('route_no', '')).strip()
        lat = data.get('lat')
        lng = data.get('lng')
        speed = data.get('speed_kmh', 20.0)
        heading = data.get('heading', 0.0)
        session_id = data.get('session_id', 'anon_commuter')

        if not route_no or lat is None or lng is None:
            return jsonify(secure_encrypt({'success': True, 'status': 'received'})), 200

        res = live_tracker.add_ping(route_id, route_no, lat, lng, speed, heading, session_id)
        return jsonify(secure_encrypt(res))
    except Exception:
        return jsonify(secure_encrypt({'success': True, 'status': 'received'})), 200

@app.route('/api/bus/<path:route_no>/live', methods=['GET'])
def get_live_buses_for_route(route_no):
    buses = live_tracker.get_live_buses(route_no)
    return jsonify(secure_encrypt({
        'success': True,
        'route_no': route_no,
        'count': len(buses),
        'active_buses': buses
    }))

@app.route('/api/bus/live/stats', methods=['GET'])
def get_overall_live_stats():
    stats = live_tracker.get_stats()
    return jsonify(secure_encrypt({
        'success': True,
        'stats': stats
    }))

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5001))
    print(f"Starting CholoKolkata Secure Backend on http://localhost:{port}")
    app.run(host='0.0.0.0', port=port, debug=False)
