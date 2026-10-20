
-- =====================================================
-- PROJECT: End-to-End E-Commerce Customer & Revenue Analytics
-- DATASET: Olist Brazilian E-Commerce
-- DATABASE: MySQL 8.0
-- FILE: 02_import_data.sql
-- PURPOSE: Import and enrich the Olist dataset
-- =====================================================

USE olist_ecommerce;

-- =====================================================
-- IMPORT CONFIGURATION
-- =====================================================
-- Replace PATH_TO_PROJECT with the absolute path to
-- the downloaded project folder before running.
--
-- Example:
-- C:/Projects/E-Commerce-Customer-Revenue-Analytics
--
-- Enable LOCAL INFILE temporarily on the MySQL server
-- and client before importing the CSV files.
--
-- Run this script only on newly created, empty tables.
-- Expected row counts exclude the CSV header.
-- =====================================================

-- =====================================================
-- TABLE 1: CUSTOMERS
-- Source: olist_customers_dataset.csv
-- Expected rows: 99,441
-- =====================================================

LOAD DATA LOCAL INFILE 'PATH_TO_PROJECT/01_Data/Raw/olist_customers_dataset.csv'
INTO TABLE customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
);

-- =====================================================
-- TABLE 2: ORDERS
-- Source: olist_orders_dataset.csv
-- Expected rows: 99,441
-- =====================================================

LOAD DATA LOCAL INFILE 'PATH_TO_PROJECT/01_Data/Raw/olist_orders_dataset.csv'
INTO TABLE orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    order_id,
    customer_id,
    order_status,
    @order_purchase_timestamp,
    @order_approved_at,
    @order_delivered_carrier_date,
    @order_delivered_customer_date,
    @order_estimated_delivery_date
)
SET
    order_purchase_timestamp =
        NULLIF(@order_purchase_timestamp, ''),
    order_approved_at =
        NULLIF(@order_approved_at, ''),
    order_delivered_carrier_date =
        NULLIF(@order_delivered_carrier_date, ''),
    order_delivered_customer_date =
        NULLIF(@order_delivered_customer_date, ''),
    order_estimated_delivery_date =
        NULLIF(@order_estimated_delivery_date, '');

-- =====================================================
-- TABLE 3: ORDER ITEMS
-- Source: olist_order_items_dataset.csv
-- Expected rows: 112,650
-- =====================================================

LOAD DATA LOCAL INFILE 'PATH_TO_PROJECT/01_Data/Raw/olist_order_items_dataset.csv'
INTO TABLE order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    order_id,
    order_item_id,
    product_id,
    seller_id,
    @shipping_limit_date,
    price,
    freight_value
)
SET
    shipping_limit_date =
        NULLIF(@shipping_limit_date, '');

-- =====================================================
-- TABLE 4: PRODUCTS
-- Source: olist_products_dataset.csv
-- Expected rows: 32,951
-- =====================================================

LOAD DATA LOCAL INFILE 'PATH_TO_PROJECT/01_Data/Raw/olist_products_dataset.csv'
INTO TABLE products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    product_id,
    @product_category_name,
    @product_name_lenght,
    @product_description_lenght,
    @product_photos_qty,
    @product_weight_g,
    @product_length_cm,
    @product_height_cm,
    @product_width_cm
)
SET
    product_category_name =
        NULLIF(@product_category_name, ''),
    product_name_lenght =
        NULLIF(@product_name_lenght, ''),
    product_description_lenght =
        NULLIF(@product_description_lenght, ''),
    product_photos_qty =
        NULLIF(@product_photos_qty, ''),
    product_weight_g =
        NULLIF(@product_weight_g, ''),
    product_length_cm =
        NULLIF(@product_length_cm, ''),
    product_height_cm =
        NULLIF(@product_height_cm, ''),
    product_width_cm =
        NULLIF(@product_width_cm, '');

-- =====================================================
-- TABLE 5: ORDER PAYMENTS
-- Source: olist_order_payments_dataset.csv
-- Expected rows: 103,886
-- =====================================================

LOAD DATA LOCAL INFILE 'PATH_TO_PROJECT/01_Data/Raw/olist_order_payments_dataset.csv'
INTO TABLE order_payments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
);

-- =====================================================
-- TABLE 6: ORDER REVIEWS
-- Source: olist_order_reviews_dataset.csv
-- Expected rows: 99,224
-- =====================================================

LOAD DATA LOCAL INFILE 'PATH_TO_PROJECT/01_Data/Raw/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    review_id,
    order_id,
    review_score,
    @review_comment_title,
    @review_comment_message,
    @review_creation_date,
    @review_answer_timestamp
)
SET
    review_comment_title =
        NULLIF(@review_comment_title, ''),
    review_comment_message =
        NULLIF(@review_comment_message, ''),
    review_creation_date =
        NULLIF(@review_creation_date, ''),
    review_answer_timestamp =
        NULLIF(@review_answer_timestamp, '');

-- =====================================================
-- TABLE 7: SELLERS
-- Source: olist_sellers_dataset.csv
-- Expected rows: 3,095
-- =====================================================

LOAD DATA LOCAL INFILE 'PATH_TO_PROJECT/01_Data/Raw/olist_sellers_dataset.csv'
INTO TABLE sellers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
);

-- =====================================================
-- TABLE 8: GEOLOCATION
-- Source: olist_geolocation_dataset.csv
-- Expected rows: 1,000,163
-- =====================================================

LOAD DATA LOCAL INFILE 'PATH_TO_PROJECT/01_Data/Raw/olist_geolocation_dataset.csv'
INTO TABLE geolocation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    geolocation_zip_code_prefix,
    @geolocation_lat,
    @geolocation_lng,
    geolocation_city,
    geolocation_state
)
SET
    geolocation_lat =
        NULLIF(@geolocation_lat, ''),
    geolocation_lng =
        NULLIF(@geolocation_lng, '');

-- =====================================================
-- TABLE 9: PRODUCT CATEGORY TRANSLATION
-- Source: product_category_name_translation.csv
-- Expected CSV rows: 71
-- =====================================================

LOAD DATA LOCAL INFILE 'PATH_TO_PROJECT/01_Data/Raw/product_category_name_translation.csv'
INTO TABLE product_category_translation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    product_category_name,
    product_category_name_english
);

-- =====================================================
-- MANUAL DATA ENRICHMENT
-- Add two missing product category translations
-- Final expected rows: 73
-- =====================================================

INSERT INTO product_category_translation (
    product_category_name,
    product_category_name_english
)
VALUES
(
    'portateis_cozinha_e_preparadores_de_alimentos',
    'portable_kitchen_and_food_preparers'
),
(
    'pc_gamer',
    'pc_gamer'
);
