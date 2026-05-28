-- View 1: Latest reading per sensor (for live KPI cards)
CREATE OR REPLACE VIEW `agrosense-493415.agrosense.vw_latest_readings` AS
SELECT
    r.*,
    f.irrigation_type,
    f.fertilizer_type
FROM `agrosense-493415.agrosense.fact_sensor_readings` r
JOIN `agrosense-493415.agrosense.dim_farms`  f  ON r.farm_id   = f.farm_id
JOIN `agrosense-493415.agrosense.dim_regions` rg ON r.region_id = rg.region_id
WHERE r.reading_ts = (
    SELECT MAX(r2.reading_ts)
    FROM `agrosense-493415.agrosense.fact_sensor_readings` r2
    WHERE r2.farm_id = r.farm_id
);

-- View 2: Zone aggregates (for heatmap and zone cards)
CREATE OR REPLACE VIEW `agrosense-493415.agrosense.vw_zone_summary` AS
SELECT
    rg.region_name,
    COUNT(DISTINCT r.farm_id)               AS active_farms,
    ROUND(AVG(r.soil_moisture_pct), 2)      AS avg_moisture,
    ROUND(AVG(r.temperature_C), 2)          AS avg_temp,
    ROUND(AVG(r.humidity_pct), 2)           AS avg_humidity,
    ROUND(AVG(r.NDVI_index), 3)             AS avg_ndvi,
    SUM(r.anomaly_flag)                     AS anomaly_count,
    ROUND(AVG(y.yield_kg_per_ha), 1)        AS avg_yield
FROM `agrosense-493415.agrosense.fact_sensor_readings` r
JOIN `agrosense-493415.agrosense.dim_regions` rg ON r.region_id = rg.region_id
LEFT JOIN `agrosense-493415.agrosense.fact_yield` y ON y.farm_id = r.farm_id
GROUP BY rg.region_name;

-- View 3: Anomaly log (for alert table on dashboard)
CREATE OR REPLACE VIEW `agrosense-493415.agrosense.vw_anomaly_log` AS
SELECT
    r.reading_id,
    r.reading_ts,
    rg.region_name,
    r.crop_type,
    r.sensor_id,
    r.farm_id,
    r.soil_moisture_pct,
    r.temperature_C,
    r.humidity_pct,
    r.anomaly_moisture,
    r.anomaly_temp,
    r.anomaly_humidity,
    CASE
        WHEN r.soil_moisture_pct < 14 OR r.temperature_C > 32 THEN 'Critical'
        WHEN r.soil_moisture_pct < 18 OR r.temperature_C > 30 THEN 'Warning'
        ELSE 'Normal'
    END AS severity
FROM `agrosense-493415.agrosense.fact_sensor_readings` r
JOIN `agrosense-493415.agrosense.dim_regions` rg ON r.region_id = rg.region_id
WHERE r.anomaly_flag = 1
ORDER BY r.reading_ts DESC
LIMIT 500;

-- View 4: Yield analysis (for Tableau yield charts)
CREATE OR REPLACE VIEW `agrosense-493415.agrosense.vw_yield_analysis` AS
SELECT
    y.yield_id,
    y.farm_id,
    rg.region_name,
    y.crop_type,
    y.sowing_date,
    y.harvest_date,
    y.total_days,
    y.yield_kg_per_ha,
    y.NDVI_index,
    f.irrigation_type,
    f.fertilizer_type,
    dc.N_avg   AS ideal_N,
    dc.P_avg   AS ideal_P,
    dc.K_avg   AS ideal_K,
    dc.ideal_ph_min,
    dc.ideal_ph_max
FROM `agrosense-493415.agrosense.fact_yield` y
JOIN `agrosense-493415.agrosense.dim_regions` rg ON y.region_id = rg.region_id
JOIN `agrosense-493415.agrosense.dim_farms`   f  ON y.farm_id   = f.farm_id
LEFT JOIN `agrosense-493415.agrosense.dim_crops` dc ON dc.crop_type = y.crop_type
                      AND dc.region_id = y.region_id;

-- View 5: Weather + sensor join (for cross-validation)
CREATE OR REPLACE VIEW `agrosense-493415.agrosense.vw_sensor_weather` AS
SELECT
    r.reading_ts,
    rg.region_name,
    r.crop_type,
    r.temperature_C      AS sensor_temp,
    w.temperature_C      AS api_temp,
    r.humidity_pct       AS sensor_humidity,
    w.humidity_pct       AS api_humidity,
    r.rainfall_mm        AS sensor_rainfall,
    w.rainfall_mm        AS api_rainfall_hourly,
    w.wind_speed_ms
FROM `agrosense-493415.agrosense.fact_sensor_readings` r
JOIN `agrosense-493415.agrosense.dim_regions` rg ON r.region_id = rg.region_id
LEFT JOIN `agrosense-493415.agrosense.fact_weather_api` w
    ON w.region_id = r.region_id
    AND DATE(w.fetch_ts) = DATE(r.reading_ts);
