import os
import sys

# cPanel Phusion Passenger WSGI entry point
# Add current directory to path
app_dir = os.path.dirname(os.path.abspath(__file__))
if app_dir not in sys.path:
    sys.path.insert(0, app_dir)

from server import app as application
