# 🌿 AgroSense Analytics
### Real-Time IoT Sensor Monitoring Pipeline for Smart Agriculture

🧰 Technologies & Tools

   ![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat&logo=python&logoColor=white)
   
   ![Jupyter](https://img.shields.io/badge/Jupyter-F37626?style=flat&logo=jupyter&logoColor=white)
 
   ![BigQuery](https://img.shields.io/badge/BigQuery-Google_Cloud-4285F4?style=flat&logo=googlebigquery&logoColor=white)

   ![Looker Studio](https://img.shields.io/badge/Looker_Studio-Dashboard-4285F4?style=flat&logo=googleanalytics&logoColor=white)

   ![pandas](https://img.shields.io/badge/pandas-ETL_Pipeline-150458?style=flat&logo=pandas&logoColor=white)

---

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Live Dashboard](#-live-dashboard)
- [Tech Stack](#-tech-stack)
- [Project Architecture](#-project-architecture)
- [Datasets](#-datasets)
- [Database Schema](#-database-schema)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [ETL Pipeline](#-etl-pipeline)
- [Live Streaming](#-live-streaming-scheduler)
- [Anomaly Detection](#-anomaly-detection)
- [Key Findings](#-key-findings)
- [Challenges & Solutions](#-challenges--solutions)
- [Future Scope](#-future-scope)

---

## 🔍 Project Overview

AgroSense Analytics is an **end-to-end real-time data analytics project** that simulates a live IoT sensor monitoring system for smart agriculture. The pipeline ingests continuous sensor readings from 500 virtual farm sensors across 5 global regions, detects anomalies, and visualizes key agricultural KPIs through an interactive live dashboard.

### What it does

```
CSV Datasets + OWM API  →  Python ETL  →  BigQuery  →  Live Scheduler  →  Looker Studio
     (Data Sources)         (pandas)     (6 Tables)    (IoT Simulation)    (Dashboard)
```

### Why it matters

Traditional agriculture lacks real-time monitoring and data-driven decision support. Farmers cannot detect crop stress, soil degradation, or irrigation inefficiency early enough to prevent yield loss. AgroSense bridges this gap with a **cloud-native IoT pipeline** that enables:

- 🌱 Real-time monitoring of soil moisture, temperature, humidity, NDVI, and pH
- ⚠️ Automated anomaly detection using IQR-based statistical analysis
- 📊 Interactive live dashboard updated every 30 seconds
- 🌍 Multi-region coverage across 5 global agricultural zones

---

## 📊 Live Dashboard

The Looker Studio dashboard connects directly to BigQuery and refreshes every 15 minutes, with live stream rows inserted every 30 seconds via the Python scheduler.

### Dashboard Panels

| Panel | Description |
|---|---|
| **KPI Strip** | Avg yield · soil moisture · NDVI · temperature · humidity · anomaly count |
| **Zone Health Monitor** | Per-region cards — yield, NDVI, moisture for all 5 zones |
| **Live Sensor Stream** | Real-time line chart — temperature + humidity over time |
| **Yield by Crop & Region** | Grouped bar chart — 5 crops × 5 regions |
| **Soil Moisture Heatmap** | 50-node sensor grid colored by moisture level |
| **Anomaly Alert Feed** | Latest 20 flagged readings — Critical / Warning / Normal |
| **NPK vs Optimal** | Actual vs ideal nitrogen, phosphorus, potassium per crop |
| **Zone Sensor Summary** | Temp · Humidity · Moisture · Rainfall per region |

---

## 🛠 Tech Stack

| Tool | Role | Version |
|---|---|---|
| **Python** | Core language — ETL, scheduling, API integration | 3.12 |
| **pandas** | Data cleaning, transformation, anomaly detection | 2.x |
| **NumPy** | Sensor noise simulation, IQR computation | 1.x |
| **Google BigQuery** | Cloud data warehouse — 6 tables, 5 views | GCP |
| **google-cloud-bigquery** | Python SDK — free-tier batch inserts | 3.x |
| **Google Looker Studio** | Live interactive dashboard connected to BigQuery | Web |
| **OpenWeatherMap API** | Real weather forecast (5 days) data per region  (API 2.5 ) | Free tier |
| **schedule** | Python IoT stream simulation scheduler | 1.x |
| **Service Account / IAM** | Secure BigQuery authentication | GCP |

---

## 🏗 Project Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        LAYER 1 — DATA SOURCES                       │
│  Smart_Farming_Crop_Yield_2024.csv  │  Crop_recommendation_         │
│        (500 rows · 22 cols)         │  multiregion.csv              │
│                                     │  (2,500 rows · 9 cols)        │
│         OpenWeatherMap 5-day/3-hour forecast data API 2.5               │
│         (5 regions · temp · humidity · rainfall · UV)               │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────────┐
│                      LAYER 2 — PYTHON ETL                           │
│  pandas cleaning  ·  null imputation  ·  crop name standardization  │
│  ET₀ computation (Hargreaves FAO-56)  ·  IQR anomaly flagging       │
│  region_id lookup from BigQuery dim_regions                         │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────────┐
│                    LAYER 3 — BIGQUERY SCHEMA                        │
│  6 native tables  ·  PKs & FKs (NOT ENFORCED)                      │
│  Partitioned by DATE(reading_ts)  ·  Clustered by region/crop       │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────────┐
│                   LAYER 4 — LIVE IoT STREAM                         │
│  scheduler.py  ·  load_table_from_json() ·  FREE tier compatible   │
│  5 rows / 30 seconds  ·  auto-loops CSV   │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────────┐
│                  LAYER 5 — ANALYTICAL VIEWS                         │
│  vw_latest_readings  ·  vw_zone_summary  ·  vw_anomaly_log         │
│  vw_yield_analysis   ·  vw_sensor_weather                           │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────────┐
│                  LAYER 6 — LOOKER STUDIO DASHBOARD                  │
│  Live refresh  ·  Region filters  ·  Anomaly alerts  ·  KPI cards   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Datasets

### 1. Smart_Farming_Crop_Yield_2024.csv
> **500 rows · 22 columns · Primary IoT source**

| Column | Type | Description |
|---|---|---|
| `farm_id` | STRING | Unique farm identifier (FARM0001–FARM0500) |
| `sensor_id` | STRING | IoT sensor ID (SENS0001–SENS0500) |
| `region` | STRING | One of 5 geographic regions |
| `crop_type` | STRING | Wheat · Rice · Maize · Soybean · Cotton |
| `soil_moisture_%` | FLOAT | Volumetric water content (10–45%) |
| `soil_pH` | FLOAT | Soil acidity level (5.5–7.5) |
| `temperature_C` | FLOAT | Ambient air temperature (°C) |
| `humidity_%` | FLOAT | Relative humidity (40–90%) |
| `rainfall_mm` | FLOAT | Seasonal accumulated rainfall |
| `sunlight_hours` | FLOAT | Daily average sunlight hours |
| `NDVI_index` | FLOAT | Vegetation health score (0.30–0.90) |
| `yield_kg_per_hectare` | FLOAT | Primary target KPI |
| `sowing_date` | DATE | Crop sowing date |
| `harvest_date` | DATE | Crop harvest date |

### 2. Crop_recommendation_multiregion.csv
> **2,500 rows · 9 columns · Custom-generated (replaces India-only original)**

100 rows per region × crop combination (5 regions × 5 crops = 25 groups × 100 = 2,500).
Each row represents ideal soil and climate conditions for that crop in that region.

| Column | Description |
|---|---|
| `N`, `P`, `K` | Ideal NPK nutrient levels (kg/ha) |
| `temperature` | Ideal temperature range (°C) |
| `humidity` | Ideal humidity range (%) |
| `ph` | Ideal soil pH |
| `rainfall` | Ideal rainfall (mm) |
| `label` | Crop name (lowercase) |
| `region` | Geographic region |

### 3. OpenWeatherMap 5-day/3-hour forecast API 2.5 
> **Live · 5 regions · ~1000 API calls/day · Free tier**

---

## 🗄 Database Schema

### Star Schema — 6 BigQuery Tables

```
                    dim_regions (PK: region_id)
                         │
          ┌──────────────┼──────────────┐
          │              │              │
    dim_farms       dim_crops    fact_weather_api
    (PK: farm_id)   (PK: crop_id) (PK: weather_id)
          │
    ┌─────┴──────┐
    │            │
fact_sensor_readings    fact_yield
(PK: reading_id)        (PK: yield_id)
  ← PRIMARY FACT →       ← SEASONAL →
  Grows continuously      500 rows
  via scheduler.py
```

### Table Summary

| Table | Type | Rows | Description |
|---|---|---|---|
| `dim_regions` | Dimension | 5 | Geographic zones with OWM coordinates |
| `dim_farms` | Dimension | 500 | Farm registry — irrigation, fertilizer, location |
| `dim_crops` | Dimension | 25 | Crop profiles per region (5×5) — NPK, ideal conditions |
| `fact_sensor_readings` | Fact | 500→∞ | **PRIMARY** — live IoT stream, partitioned by date |
| `fact_yield` | Fact | 500 | Seasonal harvest outcomes — yield kg/ha, NDVI |
| `fact_weather_api` | Fact | Hourly | OWM weather per region — temp, rain, UV, wind |

### Analytical Views

| View | Purpose |
|---|---|
| `vw_latest_readings` | Latest sensor reading per farm — powers KPI cards |
| `vw_zone_summary` | Aggregated metrics per region — powers zone cards |
| `vw_anomaly_log` | All flagged readings ordered by severity |
| `vw_yield_analysis` | Yield joined with crop ideals and farm metadata |
| `vw_sensor_weather` | Sensor readings cross-validated with OWM weather |

---

## 📂 Project Structure

```
agrosense/
├── data/
│   └── raw/
│       ├── Smart_Farming_Crop_Yield_2024.csv
│       └── Crop_recommendation_multiregion.csv
│
├── sql/
│   └── agrosense_bigquery_schema.sql   # All 6 tables + PKs + FKs + views
│
├── etl/
│   ├── etl_load.py                     # One-time CSV → BigQuery loader
│   ├── one_time_load.py                # Loads historical rows with spread timestamps
│   └── reload_historical.py            # Fixes flat-timestamp issue
│
├── scheduler_bigquery_free.py          # Live IoT stream simulator (FREE tier)
├── agrosense_key.json                  # GCP service account key (gitignored)
├── requirements.txt
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites

- Python 3.12+
- Google Cloud account (free tier)
- BigQuery dataset created (`agrosense`)
- Service account JSON key with BigQuery Admin role

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/agrosense-analytics.git
cd agrosense-analytics
```

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

**requirements.txt**
```
google-cloud-bigquery==3.11.4
pandas==2.1.0
numpy==1.25.2
schedule==1.2.0
requests==2.31.0
google-auth==2.22.0
```

### 3. Set up Google Cloud

```bash
# Create a service account at console.cloud.google.com
# IAM & Admin → Service Accounts → Create
# Grant role: BigQuery Admin
# Download JSON key → save as agrosense_key.json in project root
```

### 4. Create BigQuery schema

```bash
# Open BigQuery Console → SQL Editor
# Run agrosense_bigquery_schema.sql section by section:
# Section 1: CREATE TABLE (6 statements)
# Section 2: ADD PRIMARY KEY (6 statements)
# Section 3: ADD FOREIGN KEY (7 statements)
# Section 4: INSERT seed data for dim_regions
# Section 5: CREATE VIEW (5 statements)
```

### 5. Load initial data

```bash
python etl/etl_load.py
```

Expected output:
```
✓ Connected to BigQuery: agrosense-493415
✓ Loaded 5 rows into dim_regions
✓ Loaded 500 rows into dim_farms
✓ Loaded 25 rows into dim_crops
✓ Loaded 500 rows into fact_sensor_readings
✓ Loaded 500 rows into fact_yield
```

### 6. Start the live stream

```bash
python scheduler_bigquery_free.py
```

Expected output:
```
============================================================
  AgroSense — BigQuery FREE TIER Scheduler
  Table    : agrosense-493415.agrosense.fact_sensor_readings
  Batch    : 5 rows every 30 seconds
  Method   : load_table_from_json (FREE — no billing)
============================================================

[14:32:01] Batch #1 — inserting 5 rows...
  ✓ Inserted 5 rows | Total: 5 | Anomalies: 1
  → [1] North India     | Wheat    | Moisture:34.2% | Temp:18.1°C | ✓ Normal
  → [3] Central USA     | Maize    | Moisture:11.3% | Temp:22.1°C | ⚠ ANOMALY
```

---

## 🔄 ETL Pipeline

### Data Cleaning Steps

| Step | Action | Detail |
|---|---|---|
| 1 | Load CSVs | `pandas.read_csv()` — 500 + 2,500 rows |
| 2 | Null imputation | `irrigation_type`: 150 nulls → `"Unknown"` |
| 3 | Crop name standardization | `str.title()` → wheat → Wheat, maize → Maize |
| 4 | Compute ET₀ | Hargreaves FAO-56 formula |
| 5 | IQR anomaly detection | Flag outliers per sensor metric |
| 6 | Region ID lookup | Fetched live from `dim_regions` BigQuery table |
| 7 | Batch insert | `load_table_from_json()` — free tier compatible |

### ET₀ Formula (Hargreaves Simplified, FAO-56)

```python
ET0 = 0.0023 × (temperature_C + 17.8) × sqrt(sunlight_hours) × 0.408
```

Returns reference evapotranspiration in mm/day — the core irrigation demand signal.

---

## 📡 Live Streaming Scheduler

The scheduler (`scheduler_bigquery_free.py`) simulates a live IoT feed by:

1. Loading the 500-row Yield CSV into memory once at startup
2. Fetching `region_id` values live from BigQuery `dim_regions` table
3. Replaying rows in a continuous loop with Gaussian sensor noise added
4. Computing ET₀ and anomaly flags on each row
5. Inserting batches of 5 rows every 30 seconds using `load_table_from_json()`

```
Stream rate  : 5 rows / 30 seconds
Hourly rate  : 600 rows / hour
Daily rate   : 14,400 rows / day
Cost         : FREE (BigQuery free tier — no billing required)
```

> **Important:** This scheduler uses `load_table_from_json()` exclusively.
> `insert_rows_json()` (streaming API) is **not used** — it requires paid billing.

---

## ⚠️ Anomaly Detection

IQR-based thresholds derived from the source dataset:

| Metric | Low Threshold | High Threshold | Flag |
|---|---|---|---|
| `soil_moisture_pct` | < 12.0% | > 43.0% | `anomaly_moisture = 1` |
| `temperature_C` | < 16.0°C | > 33.0°C | `anomaly_temp = 1` |
| `humidity_pct` | < 42.0% | > 88.0% | `anomaly_humidity = 1` |
| **Overall** | — | — | `anomaly_flag = MAX(am, at, ah)` |

Severity classification in Looker Studio:

```sql
CASE
  WHEN soil_moisture_pct < 12 OR temperature_C > 33 THEN 'Critical'
  WHEN soil_moisture_pct < 18 OR temperature_C > 30 THEN 'Warning'
  ELSE 'Normal'
END AS severity
```

---

## 📈 Key Findings

### Overall KPIs (500 farms)

| Metric | Value |
|---|---|
| Average Yield | 4,033 kg/ha |
| Average NDVI | 0.602 (healthy range) |
| Average Soil Moisture | 26.75% |
| Average Temperature | 24.7°C |
| Average Humidity | 65.2% |
| Average Soil pH | 6.52 |

### Yield by Crop Type

| Crop | Avg Yield (kg/ha) |
|---|---|
| 🥇 Soybean | 4,256.8 |
| 🥈 Wheat | 4,077.6 |
| 🥉 Maize | 3,982.6 |
| Cotton | 3,925.6 |
| Rice | 3,896.2 |

### Yield by Region

| Region | Avg Yield (kg/ha) |
|---|---|
| 🥇 South India | 4,122.9 |
| 🥈 East Africa | 4,053.2 |
| 🥉 Central USA | 4,013.1 |
| North India | 3,996.2 |
| South USA | 3,984.4 |

---

## 🧩 Challenges & Solutions

| # | Challenge | Root Cause | Solution |
|---|---|---|---|
| 1 | `403 Streaming insert not allowed` | `insert_rows_json()` requires paid billing | Switched to `load_table_from_json()` — free LoadJob API |
| 2 | `EXTERNAL table — inserts blocked` | Google Sheets link created read-only external table | Deleted external table, recreated as native TABLE with JSON schema |
| 3 | Crop name mismatch across datasets | `"Corn"` vs `"Maize"` vs `"maize"` in 3 different sources | Standardized to `str.title()` in ETL — all become `"Maize"` |
| 4 | Wheat & Soybean missing from rec. dataset | Original India-only CSV had no Wheat or Soybean rows | Generated `Crop_recommendation_multiregion.csv` — 2,500 rows, 5 regions |
| 5 | `datetime.utcnow()` DeprecationWarning | Python 3.12 deprecated `datetime.utcnow()` | Replaced with `datetime.now(timezone.utc)` throughout |
| 6 | Dashboard chart gap (flat line) | All 500 historical rows loaded with identical timestamp | Reloaded with spread timestamps — 1 row every 20 minutes over 7 days |
| 7 | Smart irrigation dataset not fit for project | No region column, missing Cotton, wrong Kc for Wheat, fake light/temp data | Removed dataset entirely — Yield CSV is sufficient for streaming |

---

## 🔮 Future Scope

- [ ] **ML Crop Recommendation Model** — Random Forest classifier on Crop Rec. dataset (97%+ accuracy expected)
- [ ] **Real IoT Integration** — Replace CSV replay with MQTT protocol from physical sensors
- [ ] **Automated Irrigation Control** — Trigger alerts when ET₀ exceeds crop-specific threshold
- [ ] **Mobile Alerts** — Firebase push notifications for Critical anomaly events
- [ ] **Time-Series Forecasting** — LSTM model for yield prediction based on sensor trends
- [ ] **Multi-Season Warehouse** — Store multiple growing seasons for historical trend analysis
- [ ] **OWM Weather Enrichment** — Hourly weather writes to `fact_weather_api` for all 5 regions

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgements

- [FAO-56 Penman-Monteith Reference](http://www.fao.org/3/x0490e/x0490e00.htm) — ET₀ formula reference
- [OpenWeatherMap](https://openweathermap.org/) — Free weather API
- [Google BigQuery](https://cloud.google.com/bigquery) — Cloud data warehouse
- [Google Looker Studio](https://lookerstudio.google.com/) — Free live dashboard tool

---

<div align="center">

**Built with 🌱 for smart, data-driven agriculture**

[![GitHub](https://img.shields.io/badge/GitHub-AgroSense_Analytics-181717?style=flat&logo=github)](https://github.com/yourusername/agrosense-analytics)

</div>ideal nitrogen, phosphorus, potassium per cropZone Sensor SummaryTemp · Humidity · Moisture · Rainfall per region
