-- ============================================================
--  AgroSense Analytics — BigQuery Schema
--  Converted from MySQL v2.0
--  Version  : 3.0 (BigQuery)
--  Datasets : Smart_Farming_Crop_Yield_2024.csv (500 rows)
--             Crop_recommendation_multiregion.csv (2500 rows)
--             OpenWeatherMap Historical API
--  Project  : agrosense-493415
--  Dataset  : agrosense
--  Author   : AgroSense Analytics Project
-- ============================================================
-- HOW TO RUN:
--   1. Open BigQuery Console → SQL Editor
--   2. Run each section ONE BY ONE in order
--   3. Do NOT run the entire file at once
-- ============================================================


-- ============================================================
-- SECTION 1: CREATE TABLES
-- Run each CREATE TABLE separately
-- ============================================================


-- ------------------------------------------------------------
-- TABLE 1: dim_regions
-- Source  : Derived from Yield CSV (region column)
-- Role    : Master lookup for all 5 geographic zones
-- PK      : region_id
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `agrosense-493415.agrosense.dim_regions` (
    region_id    INT64   NOT NULL  OPTIONS(description='Surrogate PK — 1 to 5'),
    region_name  STRING  NOT NULL  OPTIONS(description='Unique region name'),
    latitude     FLOAT64 NOT NULL  OPTIONS(description='Centroid lat for OWM API'),
    longitude    FLOAT64 NOT NULL  OPTIONS(description='Centroid lon for OWM API'),
    climate_zone STRING            OPTIONS(description='e.g. Semi-Arid, Humid Continental, Tropical'),
    created_at   TIMESTAMP         OPTIONS(description='Row insert timestamp')
)
OPTIONS(description='Master lookup — 5 geographic zones');


-- ------------------------------------------------------------
-- TABLE 2: dim_crops
-- Source  : Crop_recommendation_multiregion.csv
-- Role    : Per-region crop profiles — NPK + climate ranges
-- PK      : crop_id
-- FK      : region_id → dim_regions.region_id
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `agrosense-493415.agrosense.dim_crops` (
    crop_id            INT64   NOT NULL  OPTIONS(description='Surrogate PK'),
    crop_type          STRING  NOT NULL  OPTIONS(description='Wheat|Rice|Maize|Soybean|Cotton'),
    region_id          INT64            OPTIONS(description='FK → dim_regions.region_id'),
    -- Ideal soil nutrient ranges
    N_avg              FLOAT64          OPTIONS(description='Avg nitrogen requirement kg/ha'),
    N_min              FLOAT64,
    N_max              FLOAT64,
    P_avg              FLOAT64          OPTIONS(description='Avg phosphorus requirement'),
    P_min              FLOAT64,
    P_max              FLOAT64,
    K_avg              FLOAT64          OPTIONS(description='Avg potassium requirement'),
    K_min              FLOAT64,
    K_max              FLOAT64,
    -- Ideal climate thresholds
    ideal_temp_min     FLOAT64,
    ideal_temp_max     FLOAT64,
    ideal_humidity_min FLOAT64,
    ideal_humidity_max FLOAT64,
    ideal_ph_min       FLOAT64,
    ideal_ph_max       FLOAT64,
    ideal_rainfall_min FLOAT64,
    ideal_rainfall_max FLOAT64,
    -- FAO crop coefficient
    kc_mid_season      FLOAT64          OPTIONS(description='FAO-56 Kc mid-season value'),
    created_at         TIMESTAMP        OPTIONS(description='Row insert timestamp')
)
OPTIONS(description='Crop profiles per region — 25 rows (5 crops x 5 regions)');


-- ------------------------------------------------------------
-- TABLE 3: dim_farms
-- Source  : Smart_Farming_Crop_Yield_2024.csv
-- Role    : Master farm registry — one row per physical farm
-- PK      : farm_id (natural key)
-- FK      : region_id → dim_regions.region_id
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `agrosense-493415.agrosense.dim_farms` (
    farm_id         STRING  NOT NULL  OPTIONS(description='Natural PK — FARM0001 to FARM0500'),
    region_id       INT64            OPTIONS(description='FK → dim_regions.region_id'),
    latitude        FLOAT64,
    longitude       FLOAT64,
    irrigation_type STRING           OPTIONS(description='Drip | Sprinkler | Manual | Unknown'),
    fertilizer_type STRING           OPTIONS(description='Organic | Inorganic | Mixed'),
    created_at      TIMESTAMP        OPTIONS(description='Row insert timestamp')
)
OPTIONS(description='Master farm registry — 500 farms');


-- ------------------------------------------------------------
-- TABLE 4: fact_sensor_readings  ← PRIMARY FACT TABLE
-- Source  : Smart_Farming_Crop_Yield_2024.csv
--           + Live streaming simulation (scheduler.py)
-- Role    : Every IoT sensor reading — grows continuously
-- PK      : reading_id
-- FK      : farm_id   → dim_farms.farm_id
--           region_id → dim_regions.region_id
-- NOTE    : Partitioned by DATE(reading_ts) for performance
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `agrosense-493415.agrosense.fact_sensor_readings` (
    reading_id         INT64      OPTIONS(description='Surrogate PK — auto-increment in Python'),
    farm_id            STRING     OPTIONS(description='FK → dim_farms.farm_id'),
    sensor_id          STRING     OPTIONS(description='SENS0001 to SENS0500'),
    crop_type          STRING     OPTIONS(description='Wheat|Rice|Maize|Soybean|Cotton'),
    region_id          INT64      OPTIONS(description='FK → dim_regions.region_id'),
    region_name        STRING     OPTIONS(description='Denormalized for faster Looker queries'),
    -- Timestamp
    reading_ts         TIMESTAMP  OPTIONS(description='ISO datetime of sensor reading'),
    -- Sensor measurements
    soil_moisture_pct  FLOAT64    OPTIONS(description='Volumetric water content %'),
    soil_pH            FLOAT64    OPTIONS(description='5.5 to 7.5 range'),
    temperature_C      FLOAT64    OPTIONS(description='Ambient air temp degrees C'),
    humidity_pct       FLOAT64    OPTIONS(description='Relative humidity %'),
    rainfall_mm        FLOAT64    OPTIONS(description='Accumulated rainfall mm'),
    sunlight_hours     FLOAT64    OPTIONS(description='Daily avg sunlight hours'),
    pesticide_usage_ml FLOAT64    OPTIONS(description='Pesticide applied mL/ha'),
    NDVI_index         FLOAT64    OPTIONS(description='0.30 to 0.90 vegetation health'),
    -- Computed fields
    ET0_computed       FLOAT64    OPTIONS(description='Reference ET0 mm/day — Hargreaves formula'),
    
    -- Anomaly detection flags
    anomaly_moisture   INT64      OPTIONS(description='1 = outside IQR bounds'),
    anomaly_temp       INT64      OPTIONS(description='1 = outside IQR bounds'),
    anomaly_humidity   INT64      OPTIONS(description='1 = outside IQR bounds'),
    anomaly_flag       INT64      OPTIONS(description='1 = any anomaly detected'),
    -- Metadata
    ingested_at        TIMESTAMP  OPTIONS(description='Row insert timestamp')
)
PARTITION BY DATE(reading_ts)
CLUSTER BY region_id, crop_type, anomaly_flag
OPTIONS (
    partition_expiration_days = 60
);


-- ------------------------------------------------------------
-- TABLE 5: fact_yield
-- Source  : Smart_Farming_Crop_Yield_2024.csv
-- Role    : Seasonal harvest outcomes — one row per farm
-- PK      : yield_id
-- FK      : farm_id   → dim_farms.farm_id
--           region_id → dim_regions.region_id
-- NOTE    : days_check is computed in Python (no generated
--           columns in BigQuery — unlike MySQL)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `agrosense-493415.agrosense.fact_yield` (
    yield_id        INT64   OPTIONS(description='Surrogate PK'),
    farm_id         STRING  OPTIONS(description='FK → dim_farms.farm_id'),
    crop_type       STRING  OPTIONS(description='Wheat|Rice|Maize|Soybean|Cotton'),
    region_id       INT64   OPTIONS(description='FK → dim_regions.region_id'),
    region_name     STRING  OPTIONS(description='Denormalized for faster Looker queries'),
    -- Season dates
    sowing_date     DATE    OPTIONS(description='Crop sowing date'),
    harvest_date    DATE    OPTIONS(description='Crop harvest date'),
    total_days      INT64   OPTIONS(description='harvest_date minus sowing_date'),
    -- Outcome metrics
    yield_kg_per_ha FLOAT64 OPTIONS(description='Primary target KPI — kg per hectare'),
    NDVI_index      FLOAT64 OPTIONS(description='Satellite vegetation score at harvest'),
    -- NOTE: days_check (MySQL generated column) is computed in Python ETL:
    -- days_check = 1 if (harvest_date - sowing_date).days == total_days else 0
    days_check      INT64   OPTIONS(description='1 = total_days matches date diff — computed in Python'),
    created_at      TIMESTAMP OPTIONS(description='Row insert timestamp')
)
OPTIONS(description='Seasonal harvest outcomes — 500 rows');


-- ------------------------------------------------------------
-- TABLE 6: fact_weather_api
-- Source  : OpenWeatherMap Historical API
-- Role    : External weather signal per region per timestamp
-- PK      : weather_id
-- FK      : region_id → dim_regions.region_id
-- NOTE    : Partitioned by DATE(fetch_ts) for date-level joins
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `agrosense-493415.agrosense.fact_weather_api` (
    weather_id    INT64      OPTIONS(description='Surrogate PK'),
    region_id     INT64      OPTIONS(description='FK → dim_regions.region_id'),
    region_name   STRING     OPTIONS(description='Denormalized for faster Looker queries'),
    fetch_ts      TIMESTAMP  OPTIONS(description='UTC timestamp from OWM response'),
    -- OWM fields
    temperature_C FLOAT64    OPTIONS(description='Air temperature degrees C'),
    humidity_pct  FLOAT64    OPTIONS(description='Relative humidity %'),
    wind_speed_ms FLOAT64    OPTIONS(description='Wind speed m/s'),
    rainfall_mm   FLOAT64    OPTIONS(description='Hourly rainfall from OWM mm'),
    uv_index      FLOAT64    OPTIONS(description='UV index from OWM'),
    -- Source coordinates
    api_lat       FLOAT64    OPTIONS(description='Region centroid latitude'),
    api_lon       FLOAT64    OPTIONS(description='Region centroid longitude'),
    -- NOTE: fetch_date replaces MySQL GENERATED COLUMN
    -- BigQuery does not support generated columns
    -- Use DATE(fetch_ts) directly in queries instead
    ingested_at   TIMESTAMP  OPTIONS(description='Row insert timestamp')
)
PARTITION BY DATE(fetch_ts)
OPTIONS(description='OpenWeatherMap API data — one row per region per hour');


-- ============================================================
-- SECTION 2: PRIMARY KEYS
-- Run each ALTER TABLE separately — one at a time
-- ============================================================

-- ============================================================
-- SECTION 5: ANALYTICAL VIEWS
-- BigQuery uses CREATE OR REPLACE VIEW (same as MySQL)
-- Run each CREATE VIEW separately
-- NOTE: BigQuery views do not support ORDER BY without LIMIT
--       vw_anomaly_log ORDER BY is moved inside a subquery
-- ============================================================


-- ------------------------------------------------------------
-- View 1: Latest reading per sensor (for live KPI cards)
-- NOTE: BigQuery supports this correlated subquery pattern
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW `agrosense-493415.agrosense.vw_latest_readings` AS
SELECT
    r.*,
    f.irrigation_type,
    f.fertilizer_type,
    rg.region_name AS rg_region_name
FROM `agrosense-493415.agrosense.fact_sensor_readings` r
JOIN `agrosense-493415.agrosense.dim_farms`   f
  ON r.farm_id   = f.farm_id
JOIN `agrosense-493415.agrosense.dim_regions` rg
  ON r.region_id = rg.region_id
WHERE r.reading_ts = (
    SELECT MAX(r2.reading_ts)
    FROM `agrosense-493415.agrosense.fact_sensor_readings` r2
    WHERE r2.farm_id = r.farm_id
);


-- ------------------------------------------------------------
-- View 2: Zone aggregates (for heatmap and zone cards)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW `agrosense-493415.agrosense.vw_zone_summary` AS
SELECT
    rg.region_name,
    COUNT(DISTINCT r.farm_id)          AS active_farms,
    ROUND(AVG(r.soil_moisture_pct), 2) AS avg_moisture,
    ROUND(AVG(r.temperature_C), 2)     AS avg_temp,
    ROUND(AVG(r.humidity_pct), 2)      AS avg_humidity,
    ROUND(AVG(r.NDVI_index), 3)        AS avg_ndvi,
    SUM(r.anomaly_flag)                AS anomaly_count,
    ROUND(AVG(y.yield_kg_per_ha), 1)   AS avg_yield
FROM `agrosense-493415.agrosense.fact_sensor_readings` r
JOIN `agrosense-493415.agrosense.dim_regions` rg
  ON r.region_id = rg.region_id
LEFT JOIN `agrosense-493415.agrosense.fact_yield` y
  ON y.farm_id = r.farm_id
GROUP BY rg.region_name;


-- ------------------------------------------------------------
-- View 3: Anomaly log (for alert table on dashboard)
-- NOTE: BigQuery views cannot have ORDER BY at top level
--       Use ORDER BY when querying this view in Looker Studio
--       LIMIT 500 is also not allowed in views — removed
--       Add LIMIT when querying: SELECT * FROM vw_anomaly_log LIMIT 500
-- ------------------------------------------------------------
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
JOIN `agrosense-493415.agrosense.dim_regions` rg
  ON r.region_id = rg.region_id
WHERE r.anomaly_flag = 1;
-- To query: SELECT * FROM `agrosense.vw_anomaly_log` ORDER BY reading_ts DESC LIMIT 500


-- ------------------------------------------------------------
-- View 4: Yield analysis (for Looker Studio yield charts)
-- ------------------------------------------------------------
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
    dc.N_avg        AS ideal_N,
    dc.P_avg        AS ideal_P,
    dc.K_avg        AS ideal_K,
    dc.ideal_ph_min,
    dc.ideal_ph_max
FROM `agrosense-493415.agrosense.fact_yield` y
JOIN `agrosense-493415.agrosense.dim_regions` rg
  ON y.region_id = rg.region_id
JOIN `agrosense-493415.agrosense.dim_farms`   f
  ON y.farm_id = f.farm_id
LEFT JOIN `agrosense-493415.agrosense.dim_crops` dc
  ON  dc.crop_type = y.crop_type
  AND dc.region_id = y.region_id;


-- ------------------------------------------------------------
-- View 5: Weather + sensor join (for cross-validation)
-- NOTE: DATE(w.fetch_ts) replaces MySQL fetch_date
--       generated column — BigQuery computes it inline
-- ------------------------------------------------------------
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
JOIN `agrosense-493415.agrosense.dim_regions` rg
  ON r.region_id = rg.region_id
LEFT JOIN `agrosense-493415.agrosense.fact_weather_api` w
  ON  w.region_id         = r.region_id
  AND DATE(w.fetch_ts)    = DATE(r.reading_ts);


-- ============================================================
-- SECTION 6: TEST & VERIFICATION QUERIES
-- Run these after loading data to verify everything is correct
-- ============================================================

-- Check all table counts
SELECT 'dim_regions'           AS tbl, COUNT(*) AS total_rows FROM `agrosense-493415.agrosense.dim_regions`
UNION ALL
SELECT 'dim_farms',            COUNT(*) FROM `agrosense-493415.agrosense.dim_farms`
UNION ALL
SELECT 'dim_crops',            COUNT(*) FROM `agrosense-493415.agrosense.dim_crops`
UNION ALL
SELECT 'fact_sensor_readings', COUNT(*) FROM `agrosense-493415.agrosense.fact_sensor_readings`
UNION ALL
SELECT 'fact_yield',           COUNT(*) FROM `agrosense-493415.agrosense.fact_yield`;

-- Check FK integrity — every farm_id in fact tables must exist in dim_farms
-- Should return 0 orphans
SELECT COUNT(*) AS orphan_readings
FROM `agrosense-493415.agrosense.fact_sensor_readings` r
LEFT JOIN `agrosense-493415.agrosense.dim_farms` f
  ON r.farm_id = f.farm_id
WHERE f.farm_id IS NULL;

-- Check region join works — should show 5 rows ~100 farms each
SELECT
    rg.region_name,
    COUNT(*) AS farms
FROM `agrosense-493415.agrosense.dim_farms` f
JOIN `agrosense-493415.agrosense.dim_regions` rg
  ON f.region_id = rg.region_id
GROUP BY rg.region_name
ORDER BY rg.region_name;

-- Check dim_crops has all 25 combinations (5 crops x 5 regions)
SELECT
    crop_type,
    COUNT(*) AS regions
FROM `agrosense-493415.agrosense.dim_crops`
GROUP BY crop_type
ORDER BY crop_type;

-- Check latest sensor readings (replaces MySQL refresh query)
SELECT
    reading_id,
    reading_ts,
    farm_id,
    crop_type,
    soil_moisture_pct,
    temperature_C,
    anomaly_flag
FROM `agrosense-493415.agrosense.fact_sensor_readings`
ORDER BY reading_ts DESC
LIMIT 10;

-- See all regions seeded correctly
SELECT * FROM `agrosense-493415.agrosense.dim_regions`
ORDER BY region_id;

-- See all farms loaded
SELECT * FROM `agrosense-493415.agrosense.dim_farms`
LIMIT 10;

-- See weather API data
SELECT * FROM `agrosense-493415.agrosense.fact_weather_api`
ORDER BY fetch_ts DESC
LIMIT 10;

-- Test vw_latest_readings view
SELECT * FROM `agrosense-493415.agrosense.vw_latest_readings`
LIMIT 10;

-- Verify all constraints created
SELECT
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name  AS references_table,
    ccu.column_name AS references_column
FROM
    `agrosense-493415.agrosense.INFORMATION_SCHEMA.TABLE_CONSTRAINTS` tc
LEFT JOIN
    `agrosense-493415.agrosense.INFORMATION_SCHEMA.KEY_COLUMN_USAGE` kcu
    ON tc.constraint_name = kcu.constraint_name
LEFT JOIN
    `agrosense-493415.agrosense.INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE` ccu
    ON tc.constraint_name = ccu.constraint_name
ORDER BY
    tc.table_name, tc.constraint_type;