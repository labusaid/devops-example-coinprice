from flask import Flask, jsonify
import requests
from datetime import datetime

app = Flask(__name__)


def get_crypto_price(crypto_id):
    """Helper function to fetch crypto price from CoinGecko API"""
    url = f"https://api.coingecko.com/api/v3/simple/price?ids={crypto_id}&vs_currencies=usd&include_last_updated_at=true"

    try:
        response = requests.get(url)
        response.raise_for_status()
        data = response.json()

        price = data[crypto_id]['usd']
        last_updated = datetime.fromtimestamp(data[crypto_id]['last_updated_at']).isoformat()

        return {
            "price_usd": price,
            "last_updated": last_updated
        }
    except requests.exceptions.RequestException as e:
        return {"error": f"Failed to fetch {crypto_id} price: {str(e)}"}


@app.route('/ethereum')
def get_ethereum_price():
    """Endpoint to get latest Ethereum price"""
    return jsonify(get_crypto_price('ethereum'))


@app.route('/bitcoin')
def get_bitcoin_price():
    """Endpoint to get latest Bitcoin price"""
    return jsonify(get_crypto_price('bitcoin'))


@app.errorhandler(500)
def handle_server_error(error):
    """Handle internal server errors"""
    return jsonify({"error": "Internal server error"}), 500


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')
