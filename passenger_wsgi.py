import os
import sys

# cPanel Phusion Passenger WSGI entry point
app_dir = os.path.dirname(os.path.abspath(__file__))
if app_dir not in sys.path:
    sys.path.insert(0, app_dir)

# Automatically add user & venv site-packages to sys.path
home_dir = os.path.expanduser('~')
site_packages_candidates = [
    os.path.join(app_dir, 'venv', 'lib', 'python3.11', 'site-packages'),
    os.path.join(app_dir, 'venv', 'lib', 'python3.10', 'site-packages'),
    os.path.join(app_dir, 'venv', 'lib', 'python3.9', 'site-packages'),
    os.path.join(home_dir, '.local', 'lib', 'python3.11', 'site-packages'),
    os.path.join(home_dir, '.local', 'lib', 'python3.10', 'site-packages'),
    '/home/helnovexaa/.local/lib/python3.11/site-packages',
    '/home/helnovexaa/.local/lib/python3.10/site-packages'
]

for sp in site_packages_candidates:
    if os.path.exists(sp) and sp not in sys.path:
        sys.path.insert(0, sp)

# Also support globbing venv lib site-packages
venv_lib = os.path.join(app_dir, 'venv', 'lib')
if os.path.exists(venv_lib):
    for entry in os.listdir(venv_lib):
        sp = os.path.join(venv_lib, entry, 'site-packages')
        if os.path.exists(sp) and sp not in sys.path:
            sys.path.insert(0, sp)

try:
    from server import app as application
except Exception as e:
    import traceback
    err_trace = traceback.format_exc()
    def application(environ, start_response):
        start_response('500 Internal Server Error', [('Content-Type', 'text/plain; charset=utf-8')])
        return [f"CholoKolkata WSGI Boot Error:\n{err_trace}".encode('utf-8')]
