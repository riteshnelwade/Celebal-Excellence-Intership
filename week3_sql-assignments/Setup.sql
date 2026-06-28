-- WEEK 3 SQL ASSIGNMENT 
--  Dataset: superstore_clean.csv (9994 rows)
--  Tool   : MySQL Workbench 8.0+

--  STEP 1 — CREATE DATABASE

CREATE DATABASE IF NOT EXISTS superstore_db;
USE superstore_db;
 
--  STEP 2 — DROP ALL OLD TABLES

 
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS superstore_raw;
 

--  STEP 3— CREATE superstore_raw TABLE
--  Using DATE columns (works with superstore_clean.csv)

 
CREATE TABLE superstore_raw (
    `Row ID`        INT,
    `Order ID`      VARCHAR(20),
    `Order Date`    DATE,
    `Ship Date`     DATE,
    `Ship Mode`     VARCHAR(50),
    `Customer ID`   VARCHAR(20),
    `Customer Name` VARCHAR(100),
    `Segment`       VARCHAR(50),
    `Country`       VARCHAR(50),
    `City`          VARCHAR(50),
    `State`         VARCHAR(50),
    `Postal Code`   VARCHAR(10),
    `Region`        VARCHAR(20),
    `Product ID`    VARCHAR(20),
    `Category`      VARCHAR(50),
    `Sub-Category`  VARCHAR(50),
    `Product Name`  VARCHAR(255),
    `Sales`         DECIMAL(10,4),
    `Quantity`      INT,
    `Discount`      DECIMAL(4,2),
    `Profit`        DECIMAL(10,4)
);
 
 
--   NOW IMPORT CSV — DO THIS MANUALLY:

 
--  VERIFY IMPORT
SELECT COUNT(*) AS total_rows FROM superstore_raw;


--  STEP 4 — CREATE TABLE: customers

 
CREATE TABLE customers AS
SELECT DISTINCT
    `Customer ID`   AS customer_id,
    `Customer Name` AS customer_name,
    `Segment`       AS segment,
    `Region`        AS region
FROM superstore_raw;
 

SELECT COUNT(*) AS customer_count FROM customers;

 
SELECT * FROM customers LIMIT 5;
 
 

--  STEP 5 — CREATE TABLE: orders

 
CREATE TABLE orders AS
SELECT DISTINCT
    `Order ID`    AS order_id,
    `Order Date`  AS order_date,
    `Ship Date`   AS ship_date,
    `Ship Mode`   AS ship_mode,
    `Customer ID` AS customer_id,
    `Product ID`  AS product_id,
    `Sales`       AS sales,
    `Quantity`    AS quantity,
    `Discount`    AS discount,
    `Profit`      AS profit
FROM superstore_raw;
 

SELECT COUNT(*) AS order_count FROM orders;

 
SELECT * FROM orders LIMIT 5;
 
 

--  STEP 6 — CREATE TABLE: products

CREATE TABLE products AS
SELECT DISTINCT
    `Product ID`   AS product_id,
    `Product Name` AS product_name,
    `Category`     AS category,
    `Sub-Category` AS sub_category
FROM superstore_raw;
 

SELECT COUNT(*) AS product_count FROM products;

SELECT * FROM products LIMIT 5;
 
 
--  STEP 7 — VERIFY ALL 4 TABLES

 
SELECT 'superstore_raw' AS table_name, COUNT(*) AS row_count FROM superstore_raw
UNION ALL
SELECT 'customers',COUNT(*) FROM customers
UNION ALL
SELECT 'orders',COUNT(*) FROM orders
UNION ALL
SELECT 'products',COUNT(*) FROM products;
 
--  SETUP COMPLETE ✅
