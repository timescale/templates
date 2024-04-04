

SELECT time, symbol, quantity, price
FROM ticks
WHERE symbol = '?'
ORDER BY time DESC LIMIT 1;
