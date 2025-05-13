from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def home():
    odoo_url = os.getenv('ODOO_URL', 'https://www.odoo.com/')
    pgadmin_url = os.getenv('PGADMIN_URL', 'https://www.pgadmin.org/')
    return f"<h1>Welcome to IC Group WebApp</h1><p>Odoo URL: <a href='{odoo_url}'>{odoo_url}</a></p><p>PgAdmin URL: <a href='{pgadmin_url}'>{pgadmin_url}</a></p>"

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)
