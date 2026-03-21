-- This view is required for the TrainService to efficiently calculate station-to-station trip statistics.
-- It serves as a performance optimization to avoid scanning the massive 'station_to_station_trip' table at startup.

-- 1. Create the Materialized View
CREATE MATERIALIZED VIEW station_trip_stats_mv AS
SELECT
    departing_station_code,
    arriving_station_code,
    -- Average restricted to the last 90 days
    AVG(trip_duration) FILTER (WHERE arriving_time >= (NOW() - INTERVAL '90 days')) AS recent_avg_duration,
    -- Median (50th percentile) over all available history
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY trip_duration) AS median_duration
FROM
    station_to_station_trip
GROUP BY
    departing_station_code,
    arriving_station_code
WITH DATA;

-- 2. Create a Unique Index
-- This is critical: it allows the application to refresh the view CONCURRENTLY
CREATE UNIQUE INDEX idx_station_trip_stats_mv_unique
ON station_trip_stats_mv (departing_station_code, arriving_station_code);