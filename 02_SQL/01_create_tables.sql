
-- =====================================================
-- PROJECT: End-to-End E-Commerce Customer & Revenue Analytics
-- DATASET: Olist Brazilian E-Commerce
-- DATABASE: MySQL 8.0
-- FILE: 01_create_tables.sql
-- PURPOSE: Create the database and all nine tables
-- =====================================================

-- Create database if it does not already exist
CREATE DATABASE IF NOT EXISTS olist_ecommerce;

USE olist_ecommerce;

-- =====================================================
-- TABLE 1: CUSTOMERS
-- Contains customer identifiers and location information
-- =====================================================

CREATE TABLE IF NOT EXISTS customers (
    customer_id VARCHAR(50) NOT NULL,
    customer_unique_id VARCHAR(50) DEFAULT NULL,
    customer_zip_code_prefix VARCHAR(10) DEFAULT NULL,
    customer_city VARCHAR(100) DEFAULT NULL,
    customer_state VARCHAR(2) DEFAULT NULL,

    PRIMARY KEY (customer_id)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

-- =====================================================
-- TABLE 2: ORDERS
-- Contains order status, timestamps, and customer links
-- =====================================================

CREATE TABLE IF NOT EXISTS orders (
    order_id VARCHAR(50) NOT NULL,
    customer_id VARCHAR(50) DEFAULT NULL,
    order_status VARCHAR(30) DEFAULT NULL,
    order_purchase_timestamp DATETIME DEFAULT NULL,
    order_approved_at DATETIME DEFAULT NULL,
    order_delivered_carrier_date DATETIME DEFAULT NULL,
    order_delivered_customer_date DATETIME DEFAULT NULL,
    order_estimated_delivery_date DATETIME DEFAULT NULL,

    PRIMARY KEY (order_id),

    KEY fk_orders_customers (customer_id),

    CONSTRAINT fk_orders_customers
        FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

-- =====================================================
-- TABLE 3: ORDER ITEMS
-- Contains products, sellers, prices, and shipping costs
-- =====================================================

CREATE TABLE IF NOT EXISTS order_items (
    order_id VARCHAR(50) NOT NULL,
    order_item_id INT NOT NULL,
    product_id VARCHAR(50) DEFAULT NULL,
    seller_id VARCHAR(50) DEFAULT NULL,
    shipping_limit_date DATETIME DEFAULT NULL,
    price DECIMAL(12,2) DEFAULT NULL,
    freight_value DECIMAL(12,2) DEFAULT NULL,

    PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_order_items_orders
        FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

-- =====================================================
-- TABLE 4: PRODUCTS
-- Contains product categories and physical attributes
-- =====================================================

CREATE TABLE IF NOT EXISTS products (
    product_id VARCHAR(50) NOT NULL,
    product_category_name VARCHAR(100) DEFAULT NULL,
    product_name_lenght INT DEFAULT NULL,
    product_description_lenght INT DEFAULT NULL,
    product_photos_qty INT DEFAULT NULL,
    product_weight_g INT DEFAULT NULL,
    product_length_cm INT DEFAULT NULL,
    product_height_cm INT DEFAULT NULL,
    product_width_cm INT DEFAULT NULL,

    PRIMARY KEY (product_id)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

-- =====================================================
-- TABLE 5: ORDER PAYMENTS
-- Contains payment methods, installments, and amounts
-- =====================================================

CREATE TABLE IF NOT EXISTS order_payments (
    order_id VARCHAR(50) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type VARCHAR(30) DEFAULT NULL,
    payment_installments INT DEFAULT NULL,
    payment_value DECIMAL(12,2) DEFAULT NULL,

    PRIMARY KEY (order_id, payment_sequential),

    CONSTRAINT fk_order_payments_orders
        FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

-- =====================================================
-- TABLE 6: ORDER REVIEWS
-- Contains customer ratings, comments, and review dates
-- =====================================================

CREATE TABLE IF NOT EXISTS order_reviews (
    review_record_id INT NOT NULL AUTO_INCREMENT,
    review_id VARCHAR(50) DEFAULT NULL,
    order_id VARCHAR(50) DEFAULT NULL,
    review_score INT DEFAULT NULL,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date DATETIME DEFAULT NULL,
    review_answer_timestamp DATETIME DEFAULT NULL,

    PRIMARY KEY (review_record_id),

    KEY idx_reviews_order_id (order_id),

    CONSTRAINT fk_reviews_orders
        FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

-- =====================================================
-- TABLE 7: SELLERS
-- Contains seller identifiers and geographic information
-- =====================================================

CREATE TABLE IF NOT EXISTS sellers (
    seller_id VARCHAR(50) NOT NULL,
    seller_zip_code_prefix VARCHAR(10) DEFAULT NULL,
    seller_city VARCHAR(100) DEFAULT NULL,
    seller_state VARCHAR(2) DEFAULT NULL,

    PRIMARY KEY (seller_id)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

-- =====================================================
-- TABLE 8: GEOLOCATION
-- Contains Brazilian ZIP codes and geographic coordinates
-- =====================================================

CREATE TABLE IF NOT EXISTS geolocation (
    geolocation_id INT NOT NULL AUTO_INCREMENT,
    geolocation_zip_code_prefix VARCHAR(10) DEFAULT NULL,
    geolocation_lat DOUBLE DEFAULT NULL,
    geolocation_lng DOUBLE DEFAULT NULL,
    geolocation_city VARCHAR(100) DEFAULT NULL,
    geolocation_state VARCHAR(2) DEFAULT NULL,

    PRIMARY KEY (geolocation_id),

    KEY idx_geolocation_zip (geolocation_zip_code_prefix)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

-- =====================================================
-- TABLE 9: PRODUCT CATEGORY TRANSLATION
-- Translates product categories from Portuguese to English
-- =====================================================

CREATE TABLE IF NOT EXISTS product_category_translation (
    product_category_name VARCHAR(100) NOT NULL,
    product_category_name_english VARCHAR(100) DEFAULT NULL,

    PRIMARY KEY (product_category_name)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;
