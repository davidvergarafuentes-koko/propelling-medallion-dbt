-- Run once as ACCOUNTADMIN, after setup.sql and after the first dbt build (Gold must exist).
-- Prepares a schema for the Streamlit dashboard and lets the read-only REPORTER role own it.
USE ROLE ACCOUNTADMIN;

-- Apps live in their own schema, apart from the data layers
CREATE SCHEMA IF NOT EXISTS PROPELLING_DB.APPS;

-- REPORTER can create the app there, and nothing else
GRANT USAGE            ON SCHEMA PROPELLING_DB.APPS TO ROLE REPORTER;
GRANT CREATE STREAMLIT ON SCHEMA PROPELLING_DB.APPS TO ROLE REPORTER;
GRANT CREATE STAGE     ON SCHEMA PROPELLING_DB.APPS TO ROLE REPORTER;

-- The FUTURE grants in setup.sql only cover tables created after them. This covers tables that already exist.
GRANT SELECT ON ALL TABLES IN SCHEMA PROPELLING_DB.GOLD TO ROLE REPORTER;
GRANT SELECT ON ALL VIEWS  IN SCHEMA PROPELLING_DB.GOLD TO ROLE REPORTER;

-- Only for the container runtime: uncomment if the Create Streamlit dialog shows a "Compute pool" field
-- GRANT USAGE ON COMPUTE POOL SYSTEM_COMPUTE_POOL_CPU TO ROLE REPORTER;

-- Give REPORTER to the person who will build the app. Find the name with SELECT CURRENT_USER();
-- Keep the double quotes if the name is in lowercase.
GRANT ROLE REPORTER TO USER "<your_user>";

-- Check: should return 6001215
USE ROLE REPORTER;
USE WAREHOUSE TRANSFORM_WH;
SELECT COUNT(*) FROM PROPELLING_DB.GOLD.FCT_SALES;
