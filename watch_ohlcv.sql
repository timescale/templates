-- Watch OHLCV data from minute, hour, and day frames.

select * from ohlcv_1m order by time desc limit 3;
select * from ohlc_1h order by time desc limit 3;
select * from ohlc_1d order by time desc limit 3;
