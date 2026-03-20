from flask import Flask, jsonify
import os
import psycopg2

app = Flask(__name__)

def get_db_connection():
    conn = psycopg2.connect(
        host=os.environ.get('DB_HOST', 'db'),
        database=os.environ.get('DB_NAME', 'appdb'),
        user=os.environ.get('DB_USER', 'postgres'),
        password=os.environ.get('DB_PASSWORD', 'postgres')
    )
    return conn

@app.route('/health')
def health_check():
    return jsonify({"status": "healthy"}), 200

@app.route('/api/data')
def get_data():
    try:
        conn = get_db_connection()
        conn.close()
        return jsonify({"message": "Successfully connected to the PostgreSQL database!"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)