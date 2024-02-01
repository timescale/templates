#https://pypi.org/project/websocket_client/
from datetime import datetime
import websocket
import json
import os
import psycopg2

config = {'DB_USER': os.environ['DB_USER'],
         'DB_PASS': os.environ['DB_PASS'],
         'DB_HOST': os.environ['DB_HOST'],
         'DB_PORT': os.environ['DB_PORT'],
         'DB_NAME': os.environ['DB_NAME'],
         'API_KEY': os.environ['API_KEY']}


conn = psycopg2.connect(database=config['DB_NAME'],
                           host=config['DB_HOST'],
                           user=config['DB_USER'],
                           password=config['DB_PASS'],
                           port=config['DB_PORT'])
conn.autocommit = True

def execute(sql):
    cursor = conn.cursor()
    cursor.execute(sql)
    cursor.close()

setup_db = open('../ticks.sql', 'r').read()

execute(setup_db)


SYMBOLS = ["USDTBRL","BTCUSDT", "ETHUSDT", "USDTBIDR"]
for symbol in SYMBOLS:
    cursor = conn.cursor()
    cursor.execute("SELECT symbol FROM symbols WHERE symbol = %s;", (symbol,))
    if cursor.rowcount == 0:
        cursor.execute("INSERT INTO symbols (symbol) VALUES (%s);", (symbol,))
        conn.commit()


INSERT = f"""
  INSERT INTO ticks ( time, symbol, price, volume)
  VALUES (%s, %s, %s, %s);
"""

# Message payload example
# {"data":[
#    {"c":null,"p":5.583,"s":"BINANCE:USDTBRL","t":1636631765675,"v":8060.2},
#    {"c":null,"p":5.583,"s":"BINANCE:USDTBRL","t":1636631765773,"v":298.5},
#    {"c":null,"p":5.583,"s":"BINANCE:USDTBRL","t":1636631765995,"v":143.3}
#  ], "type":"trade"}
def on_message(ws, message):
    data = json.loads(message)
    if data["type"] == "trade":
        cursor = conn.cursor()
        for event in data["data"]:
            time = datetime.utcfromtimestamp(event['t'] / 1e3).strftime('%Y-%m-%d %H:%M:%S')
            # split symbol from exchange "binance:BTCUSDT" -> "BTCUSDT
            symbol = event['s'].split(':')[1]
            trade = (time, symbol, event['p'], event['v'])
            print(f"\r {trade}", end='')
            cursor.execute(INSERT, trade)

        conn.commit()
        cursor.close()
    else:
        print(message)

def on_error(ws, error):
    print(error)
    ws.close()
    start()

def on_close(ws):
    print("### closed ###")
    start()

def on_open(ws):
#    ws.send('{"type":"subscribe","symbol":"AMZN"}')
#    ws.send('{"type":"subscribe","symbol":"BINANCE:BTCUSDT"}')
    for symbol in SYMBOLS:
        subscription = '{"type":"subscribe","symbol": "BINANCE:'+symbol+'"}'
        ws.send(subscription)
    #ws.send('{"type":"subscribe","symbol":"IC MARKETS:1"}')

def start():
    print("starting...")
    url = f"wss://ws.finnhub.io?token={config['API_KEY']}"
    ws = websocket.WebSocketApp(url,
                              on_message = on_message,
                              on_error = on_error,
                              on_close = on_close)
    ws.on_open = on_open
    ws.run_forever()
if __name__ == "__main__":
    start()


