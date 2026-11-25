import os

# Auto-load .env file if present
env_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env')
if os.path.exists(env_file):
    with open(env_file, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                k, v = line.split('=', 1)
                os.environ.setdefault(k.strip(), v.strip())

class Config:
    DB_HOST = os.environ.get('DB_HOST', 'localhost')
    DB_USER = os.environ.get('DB_USER', 'helnovexaa_bus')
    DB_PASSWORD = os.environ.get('DB_PASSWORD', 'Soumojit1234@')
    DB_NAME = os.environ.get('DB_NAME', 'helnovexaa_buskolkata')
    DB_PORT = int(os.environ.get('DB_PORT', 3306))
    
    SECRET_KEY = os.environ.get('SECRET_KEY', 'KolkataTransitSecureKey2026WIMT!')
    WEBSITE_URL = os.environ.get('WEBSITE_URL', 'http://cholokolkata.online/')
    DEBUG = os.environ.get('DEBUG', 'False').lower() in ('true', '1')
