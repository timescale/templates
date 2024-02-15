-- Watch OHLCV data from minute, hour, and day frames.

SELECT
    m.bucket AS min_bucket,
    h.bucket AS hour_bucket,
    d.bucket AS day_bucket,
    m.high as high_minute,
    m.low as low_minute,
    m.open as open_minute,
    m.close as close_minute,
    h.high as high_hour,
    h.low as low_hour,
    h.open as open_hour,
    h.close as close_hour,
    d.high as high_day,
    d.low as low_day,
    d.open as open_day,
    d.close as close_day
FROM
    (SELECT * FROM ohlcv_1m ORDER BY bucket DESC LIMIT 1) m
JOIN
    (SELECT * FROM ohlcv_1h ORDER BY bucket DESC LIMIT 1) h
    ON h.bucket = time_bucket('1 h', m.bucket) and h.symbol = m.symbol
JOIN
    (SELECT * FROM ohlcv_1d ORDER BY bucket DESC LIMIT 1) d
    ON d.bucket = time_bucket('1 d', m.bucket) and d.symbol = m.symbol;


--select * from timescaledb_information.job_errors order by finish_time desc limit 5;

-- Watch the previous query.

\watch
