USE ROLE ROLE_HOL_TIMESERIES;
USE HOL_TIMESERIES.TRANSFORM;

-- Setup Transform Tabls
-- Tag Metadata (Dimension)
CREATE OR REPLACE TABLE HOL_TIMESERIES.TRANSFORM.TS_TAG_METADATA (
    TAGKEY NUMBER NOT NULL,
    NAMESPACE VARCHAR,
    TAGNAME VARCHAR NOT NULL,
    TAGALIAS ARRAY,
    TAGDESCRIPTION VARCHAR,
    TAGUOM VARCHAR,
    TAGDATATYPE VARCHAR,
    INGESTION_TIMESTAMP TIMESTAMP_NTZ,
    CONSTRAINT PK_TSD_TAG_METADATA PRIMARY KEY (TAGKEY) RELY
);

SELECT GET_DDL('TABLE','HOL_TIMESERIES.TRANSFORM.TS_TAG_METADATA');

CREATE OR REPLACE TABLE HOL_TIMESERIES.TRANSFORM.TS_TAG_READINGS (
    TAGKEY NUMBER NOT NULL,
    TS TIMESTAMP_NTZ NOT NULL,
    VAL VARCHAR,
    VAL_NUMERIC FLOAT,
    INGESTION_TIMESTAMP TIMESTAMP_NTZ,
    CONSTRAINT FK_TSD_TAG_READINGS FOREIGN KEY (TAGKEY) REFERENCES HOL_TIMESERIES.TRANSFORM.TS_TAG_METADATA (TAGKEY) RELY
);

SELECT GET_DDL('TABLE','HOL_TIMESERIES.TRANSFORM.TS_TAG_READINGS');

-- Check Data
SELECT * FROM HOL_TIMESERIES.STAGING.RAW_TS_WITSML_DATA LIMIT 10;

-- Eplore
-- Tag Metadata
SELECT
    GET(META.VALUE, '@') AS LOGMETA_ATTR,
    GET(META.VALUE, '$') AS LOGMETA_VAL,
    'WITSML' AS NAMESPACE,
    GET(XMLGET(XMLGET(RECORD_CONTENT, 'log'), 'nameWell'), '$')::VARCHAR AS NAMEWELL,
    GET(XMLGET(META.VALUE, 'mnemonic'), '$') AS MNEMONIC,
    GET(XMLGET(META.VALUE, 'classWitsml'), '$') AS CLASSWITSML,
    GET(XMLGET(META.VALUE, 'unit'), '$') AS UNIT,
    GET(XMLGET(META.VALUE, 'mnemAlias'), '$') AS MNEMALIAS,
    GET(XMLGET(META.VALUE, 'curveDescription'), '$') AS CURVEDESCRIPTION,
    GET(XMLGET(META.VALUE, 'typeLogData'), '$') AS TYPELOGDATA
FROM HOL_TIMESERIES.STAGING.RAW_TS_WITSML_DATA,
LATERAL FLATTEN(INPUT => GET(XMLGET(RECORD_CONTENT, 'log'), '$')) META
WHERE LOGMETA_ATTR = 'logCurveInfo'
;

-- Data Query
SELECT
    GET(data.value, '@') as LOGDATA_ATTR,
    GET(data.value, '$') as LOGDATA_VAL,
FROM HOL_TIMESERIES.STAGING.RAW_TS_WITSML_DATA,
LATERAL FLATTEN(INPUT => GET(XMLGET(XMLGET(RECORD_CONTENT, 'log'), 'logData'), '$')) data
WHERE LOGDATA_ATTR = 'data'
;

-- Data
SELECT
    GET(data.value, '@') as LOGDATA_ATTR,
    GET(data.value, '$') as LOGDATA_VAL,
    'WITSML' as NAMESPACE,
    GET(XMLGET(XMLGET(RECORD_CONTENT, 'log'), 'nameWell'), '$')::varchar as NAMEWELL,
    SPLIT_PART(LOGDATA_VAL,',', 1) as Time,
    SPLIT_PART(LOGDATA_VAL,',', 2) as TRIPFILL,
    SPLIT_PART(LOGDATA_VAL,',', 3) as PIT_TRIPOUT,
    SPLIT_PART(LOGDATA_VAL,',', 4) as JOINTSDONE,
    SPLIT_PART(LOGDATA_VAL,',', 5) as TRIPPVT,
    SPLIT_PART(LOGDATA_VAL,',', 6) as TRIPCEXPFILL,
    SPLIT_PART(LOGDATA_VAL,',', 7) as JOINTSTOGO,
    SPLIT_PART(LOGDATA_VAL,',', 8) as EditFlag,
    SPLIT_PART(LOGDATA_VAL,',', 9) as RigActivityCode,
    SPLIT_PART(LOGDATA_VAL,',', 10) as TRIPPULL,
    SPLIT_PART(LOGDATA_VAL,',', 11) as TRIPCFILL,
    SPLIT_PART(LOGDATA_VAL,',', 12) as FLOWOUT,
    SPLIT_PART(LOGDATA_VAL,',', 13) as TRIPINSLIPS,
    SPLIT_PART(LOGDATA_VAL,',', 14) as Depth,
    SPLIT_PART(LOGDATA_VAL,',', 15) as TRIPRUN,
    SPLIT_PART(LOGDATA_VAL,',', 16) as STANDSTOGO,
    SPLIT_PART(LOGDATA_VAL,',', 17) as HKLD,
    SPLIT_PART(LOGDATA_VAL,',', 18) as INSLIPS_STATUS,
    SPLIT_PART(LOGDATA_VAL,',', 19) as PIT_TRIPIN,
    SPLIT_PART(LOGDATA_VAL,',', 20) as TRIPOUTSLIPS,
    SPLIT_PART(LOGDATA_VAL,',', 21) as TRIPNUM,
    SPLIT_PART(LOGDATA_VAL,',', 22) as TRIPEXPPVT,
    SPLIT_PART(LOGDATA_VAL,',', 23) as FLOWOUTPC,
    SPLIT_PART(LOGDATA_VAL,',', 24) as TRIPREAMFLAG,
    SPLIT_PART(LOGDATA_VAL,',', 25) as TRIPEXPFILL,
    SPLIT_PART(LOGDATA_VAL,',', 26) as BLOCKCOMP,
    SPLIT_PART(LOGDATA_VAL,',', 27) as STANDSDONE
FROM HOL_TIMESERIES.STAGING.RAW_TS_WITSML_DATA,
LATERAL FLATTEN(INPUT => GET(XMLGET(XMLGET(RECORD_CONTENT, 'log'), 'logData'), '$')) data
WHERE LOGDATA_ATTR = 'data'
;

-- Column List
SELECT
    GET(XMLGET(XMLGET(XMLGET(RECORD_CONTENT, 'log'), 'logData'), 'mnemonicList'), '$') AS MNEMONICLIST
FROM HOL_TIMESERIES.STAGING.RAW_TS_WITSML_DATA
;

-- Transform and ingest the Tag metadata
INSERT INTO HOL_TIMESERIES.TRANSFORM.TS_TAG_METADATA
SELECT
    (SELECT NVL(MAX(TAGKEY),0) FROM HOL_TIMESERIES.TRANSFORM.TS_TAG_METADATA) + ROW_NUMBER() OVER (PARTITION BY NULL ORDER BY NULL) AS TAGKEY,
    SRC.NAMESPACE::VARCHAR AS NAMESPACE,
    UPPER(CONCAT('/', TRIM(SRC.NAMESPACE), '/', TRIM(SRC.NAMEWELL), '/', TRIM(SRC.MNEMONIC)))::VARCHAR AS TAGNAME,
    TO_ARRAY(CONCAT('/', TRIM(SRC.NAMESPACE), '/', TRIM(SRC.NAMEWELL), '/', TRIM(SRC.MNEMALIAS))) AS TAGALIAS,
    SRC.CURVEDESCRIPTION::VARCHAR AS TAGDESCRIPTION,
    SRC.UNIT::VARCHAR AS TAGUOM,
    SRC.TYPELOGDATA::VARCHAR AS TAGDATATYPE,
    SYSDATE() AS INGESTION_TIMESTAMP
FROM (
SELECT
    GET(META.VALUE, '@') AS LOGMETA_ATTR,
    GET(META.VALUE, '$') AS LOGMETA_VAL,
    'WITSML' AS NAMESPACE,
    GET(XMLGET(XMLGET(RECORD_CONTENT, 'log'), 'nameWell'), '$')::VARCHAR AS NAMEWELL,
    GET(XMLGET(META.VALUE, 'mnemonic'), '$') AS MNEMONIC,
    GET(XMLGET(META.VALUE, 'classWitsml'), '$') AS CLASSWITSML,
    GET(XMLGET(META.VALUE, 'unit'), '$') AS UNIT,
    GET(XMLGET(META.VALUE, 'mnemAlias'), '$') AS MNEMALIAS,
    GET(XMLGET(META.VALUE, 'curveDescription'), '$') AS CURVEDESCRIPTION,
    GET(XMLGET(META.VALUE, 'typeLogData'), '$') AS TYPELOGDATA
FROM HOL_TIMESERIES.STAGING.RAW_TS_WITSML_DATA,
LATERAL FLATTEN(INPUT => GET(XMLGET(RECORD_CONTENT, 'log'), '$')) META
WHERE LOGMETA_ATTR = 'logCurveInfo'
ORDER BY MNEMONIC
) SRC
WHERE NOT EXISTS (
    SELECT 1 FROM HOL_TIMESERIES.TRANSFORM.TS_TAG_METADATA TGT
    WHERE TGT.TAGNAME = TAGNAME
)
ORDER BY TAGNAME
;

-- Review Tag Metadata
SELECT * FROM HOL_TIMESERIES.TRANSFORM.TS_TAG_METADATA;

-- Transform and ingest the readings dataset
INSERT INTO HOL_TIMESERIES.TRANSFORM.TS_TAG_READINGS
SELECT
    META.TAGKEY,
    --TRIM(CONCAT(SRC.NAMESPACE, '/', SRC.NAMEWELL, '/', SRC.MNEMONIC))::VARCHAR AS TAGNAME,
    SRC.TIME::TIMESTAMP_NTZ AS TS,
    SRC.VAL::VARCHAR AS VAL,
    TRY_CAST(SRC.VAL::VARCHAR AS FLOAT) AS VAL_NUMERIC,
    SYSDATE() AS INGESTION_TIMESTAMP
FROM (
SELECT
    GET(data.value, '@') as LOGDATA_ATTR,
    GET(data.value, '$') as LOGDATA_VAL,
    'WITSML' as NAMESPACE,
    GET(XMLGET(XMLGET(RECORD_CONTENT, 'log'), 'nameWell'), '$')::varchar as NAMEWELL,
    SPLIT_PART(LOGDATA_VAL,',', 1) as TIME,
    SPLIT_PART(LOGDATA_VAL,',', 2) as TRIPFILL,
    SPLIT_PART(LOGDATA_VAL,',', 3) as PIT_TRIPOUT,
    SPLIT_PART(LOGDATA_VAL,',', 4) as JOINTSDONE,
    SPLIT_PART(LOGDATA_VAL,',', 5) as TRIPPVT,
    SPLIT_PART(LOGDATA_VAL,',', 6) as TRIPCEXPFILL,
    SPLIT_PART(LOGDATA_VAL,',', 7) as JOINTSTOGO,
    SPLIT_PART(LOGDATA_VAL,',', 8) as EDITFLAG,
    SPLIT_PART(LOGDATA_VAL,',', 9) as RIGACTIVITYCODE,
    SPLIT_PART(LOGDATA_VAL,',', 10) as TRIPPULL,
    SPLIT_PART(LOGDATA_VAL,',', 11) as TRIPCFILL,
    SPLIT_PART(LOGDATA_VAL,',', 12) as FLOWOUT,
    SPLIT_PART(LOGDATA_VAL,',', 13) as TRIPINSLIPS,
    SPLIT_PART(LOGDATA_VAL,',', 14) as DEPTH,
    SPLIT_PART(LOGDATA_VAL,',', 15) as TRIPRUN,
    SPLIT_PART(LOGDATA_VAL,',', 16) as STANDSTOGO,
    SPLIT_PART(LOGDATA_VAL,',', 17) as HKLD,
    SPLIT_PART(LOGDATA_VAL,',', 18) as INSLIPS_STATUS,
    SPLIT_PART(LOGDATA_VAL,',', 19) as PIT_TRIPIN,
    SPLIT_PART(LOGDATA_VAL,',', 20) as TRIPOUTSLIPS,
    SPLIT_PART(LOGDATA_VAL,',', 21) as TRIPNUM,
    SPLIT_PART(LOGDATA_VAL,',', 22) as TRIPEXPPVT,
    SPLIT_PART(LOGDATA_VAL,',', 23) as FLOWOUTPC,
    SPLIT_PART(LOGDATA_VAL,',', 24) as TRIPREAMFLAG,
    SPLIT_PART(LOGDATA_VAL,',', 25) as TRIPEXPFILL,
    SPLIT_PART(LOGDATA_VAL,',', 26) as BLOCKCOMP,
    SPLIT_PART(LOGDATA_VAL,',', 27) as STANDSDONE
FROM HOL_TIMESERIES.STAGING.RAW_TS_WITSML_DATA,
LATERAL FLATTEN(INPUT => GET(XMLGET(XMLGET(RECORD_CONTENT, 'log'), 'logData'), '$')) data
WHERE LOGDATA_ATTR = 'data'
) SRC
UNPIVOT (VAL FOR SRC.MNEMONIC IN (TRIPFILL,PIT_TRIPOUT,JOINTSDONE,TRIPPVT,TRIPCEXPFILL,JOINTSTOGO,EDITFLAG,RIGACTIVITYCODE,TRIPPULL,TRIPCFILL,FLOWOUT,TRIPINSLIPS,DEPTH,TRIPRUN,STANDSTOGO,HKLD,INSLIPS_STATUS,PIT_TRIPIN,TRIPOUTSLIPS,TRIPNUM,TRIPEXPPVT,FLOWOUTPC,TRIPREAMFLAG,TRIPEXPFILL,BLOCKCOMP,STANDSDONE))
INNER JOIN HOL_TIMESERIES.TRANSFORM.TS_TAG_METADATA META ON META.TAGNAME = TRIM(CONCAT('/', TRIM(SRC.NAMESPACE), '/', TRIM(SRC.NAMEWELL), '/', TRIM(SRC.MNEMONIC)))::VARCHAR
WHERE NOT EXISTS (
    SELECT 1 FROM HOL_TIMESERIES.TRANSFORM.TS_TAG_READINGS TGT
    WHERE TGT.TAGKEY = TAGKEY AND TGT.TS = TS
)
ORDER BY TAGKEY, TS;

-- Review Tag Readings
SELECT * FROM HOL_TIMESERIES.TRANSFORM.TS_TAG_READINGS;

SELECT GET(XMLGET(XMLGET(XMLGET(RECORD_CONTENT, 'log'), 'logData'), 'mnemonicList'), '$') FROM HOL_TIMESERIES.STAGING.RAW_TS_WITSML_DATA;
-- TS,TRIPFILL,PIT_TRIPOUT,JOINTSDONE,TRIPPVT,TRIPCEXPFILL,JOINTSTOGO,EDITFLAG,RIGACTIVITYCODE,TRIPPULL,TRIPCFILL,FLOWOUT,TRIPINSLIPS,DEPTH,TRIPRUN,STANDSTOGO,HKLD,INSLIPS_STATUS,PIT_TRIPIN,TRIPOUTSLIPS,TRIPNUM,TRIPEXPPVT,FLOWOUTPC,TRIPREAMFLAG,TRIPEXPFILL,BLOCKCOMP,STANDSDONE
-- https://frombitumentobinary.com/other-witsml.html
