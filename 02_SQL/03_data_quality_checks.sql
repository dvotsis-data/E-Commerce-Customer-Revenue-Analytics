-- =====================================================
-- PROJECT: End-to-End E-Commerce Customer & Revenue Analytics
-- DATASET: Olist Brazilian E-Commerce
-- DATABASE: MySQL 8.0
-- FILE: 03_data_quality_checks.sql
-- PURPOSE: Validate data quality and integrity
-- =====================================================

USE olist_ecommerce;

-- =====================================================
-- CHECK 1: ROW COUNT VALIDATION
-- Verify imported records across all nine tables
-- =====================================================

SELECT 'customers' AS table_name, COUNT(*) AS total_rows FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'product_category_translation', COUNT(*) FROM product_category_translation;


-- =====================================================
-- CHECK 2: MISSING VALUES - CUSTOMERS
-- Identify NULL values in customer attributes
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(customer_id IS NULL) AS null_customer_id,
    SUM(customer_unique_id IS NULL) AS null_customer_unique_id,
    SUM(customer_zip_code_prefix IS NULL) AS null_zip_code,
    SUM(customer_city IS NULL) AS null_city,
    SUM(customer_state IS NULL) AS null_state
FROM customers;


-- =====================================================
-- CHECK 3: MISSING VALUES - ORDERS
-- Identify NULL values in order attributes and dates
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(order_id IS NULL) AS null_order_id,
    SUM(customer_id IS NULL) AS null_customer_id,
    SUM(order_status IS NULL) AS null_order_status,
    SUM(order_purchase_timestamp IS NULL) AS null_purchase_date,
    SUM(order_approved_at IS NULL) AS null_approval_date,
    SUM(order_delivered_carrier_date IS NULL) AS null_carrier_date,
    SUM(order_delivered_customer_date IS NULL) AS null_delivery_date,
    SUM(order_estimated_delivery_date IS NULL) AS null_estimated_date
FROM orders;


-- =====================================================
-- CHECK 4: MISSING DELIVERY DATES BY ORDER STATUS
-- Investigate missing delivery dates across order statuses
-- =====================================================

SELECT
    order_status,
    COUNT(*) AS total_orders,
    SUM(order_delivered_customer_date IS NULL) AS missing_delivery_dates,
    ROUND(
        100.0 * SUM(order_delivered_customer_date IS NULL) / COUNT(*),
        2
    ) AS missing_delivery_pct
FROM orders
GROUP BY order_status
ORDER BY missing_delivery_dates DESC;


-- =====================================================
-- CHECK 5: DELIVERED ORDERS WITHOUT DELIVERY DATES
-- Identify inconsistencies between status and delivery date
-- =====================================================

SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM orders
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NULL
ORDER BY order_purchase_timestamp;


-- =====================================================
-- CHECK 6: EMPTY STRINGS - CUSTOMERS
-- Identify blank values in customer text attributes
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(TRIM(customer_id) = '') AS empty_customer_id,
    SUM(TRIM(customer_unique_id) = '') AS empty_customer_unique_id,
    SUM(TRIM(customer_city) = '') AS empty_city,
    SUM(TRIM(customer_state) = '') AS empty_state
FROM customers;


-- =====================================================
-- CHECK 7: MISSING VALUES - ORDER ITEMS
-- Identify NULL values in order item attributes
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(order_id IS NULL) AS null_order_id,
    SUM(order_item_id IS NULL) AS null_order_item_id,
    SUM(product_id IS NULL) AS null_product_id,
    SUM(seller_id IS NULL) AS null_seller_id,
    SUM(shipping_limit_date IS NULL) AS null_shipping_date,
    SUM(price IS NULL) AS null_price,
    SUM(freight_value IS NULL) AS null_freight
FROM order_items;


-- =====================================================
-- CHECK 8: PRICE AND FREIGHT VALIDATION
-- Identify negative and zero values in order items
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(price < 0) AS negative_prices,
    SUM(price = 0) AS zero_prices,
    SUM(freight_value < 0) AS negative_freight,
    SUM(freight_value = 0) AS zero_freight,
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    MIN(freight_value) AS min_freight,
    MAX(freight_value) AS max_freight
FROM order_items;


-- =====================================================
-- CHECK 9: MISSING VALUES - PRODUCTS
-- Identify NULL values in product attributes
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(product_id IS NULL) AS null_product_id,
    SUM(product_category_name IS NULL) AS null_category,
    SUM(product_name_lenght IS NULL) AS null_name_length,
    SUM(product_description_lenght IS NULL) AS null_description_length,
    SUM(product_photos_qty IS NULL) AS null_photos,
    SUM(product_weight_g IS NULL) AS null_weight,
    SUM(product_length_cm IS NULL) AS null_length,
    SUM(product_height_cm IS NULL) AS null_height,
    SUM(product_width_cm IS NULL) AS null_width
FROM products;


-- =====================================================
-- CHECK 10: PRODUCT METADATA COMPLETENESS
-- Investigate overlapping missing product attributes
-- =====================================================

SELECT
    COUNT(*) AS total_products,
    SUM(
        product_category_name IS NULL
        AND product_name_lenght IS NULL
        AND product_description_lenght IS NULL
        AND product_photos_qty IS NULL
    ) AS all_four_missing,
    SUM(
        product_category_name IS NULL
        AND (
            product_name_lenght IS NOT NULL
            OR product_description_lenght IS NOT NULL
            OR product_photos_qty IS NOT NULL
        )
    ) AS category_only_or_partial_missing,
    SUM(
        product_category_name IS NOT NULL
        AND (
            product_name_lenght IS NULL
            OR product_description_lenght IS NULL
            OR product_photos_qty IS NULL
        )
    ) AS other_metadata_missing
FROM products;


-- =====================================================
-- CHECK 11: REVENUE IMPACT OF MISSING CATEGORIES
-- Assess sales value associated with uncategorized products
-- =====================================================

SELECT
    CASE
        WHEN p.product_category_name IS NULL THEN 'Missing Category'
        ELSE 'Known Category'
    END AS category_status,
    COUNT(DISTINCT p.product_id) AS unique_products_sold,
    COUNT(oi.order_id) AS order_items,
    COUNT(DISTINCT oi.order_id) AS unique_orders,
    ROUND(SUM(oi.price), 2) AS item_revenue
FROM products p
INNER JOIN order_items oi
    ON p.product_id = oi.product_id
GROUP BY category_status
ORDER BY item_revenue DESC;


-- =====================================================
-- CHECK 12: PRODUCT DIMENSION VALIDATION
-- Identify invalid or missing weight and dimensions
-- =====================================================

SELECT
    COUNT(*) AS total_products,
    SUM(product_weight_g IS NULL) AS null_weight,
    SUM(product_weight_g <= 0) AS invalid_weight,
    SUM(product_length_cm IS NULL) AS null_length,
    SUM(product_length_cm <= 0) AS invalid_length,
    SUM(product_height_cm IS NULL) AS null_height,
    SUM(product_height_cm <= 0) AS invalid_height,
    SUM(product_width_cm IS NULL) AS null_width,
    SUM(product_width_cm <= 0) AS invalid_width
FROM products;


-- =====================================================
-- CHECK 13: INVALID PRODUCT WEIGHT DETAILS
-- Investigate products with zero or negative weight
-- =====================================================

SELECT
    product_id,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM products
WHERE product_weight_g <= 0
ORDER BY product_weight_g, product_id;


-- =====================================================
-- CHECK 14: MISSING VALUES - ORDER PAYMENTS
-- Identify NULL values in payment attributes
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(order_id IS NULL) AS null_order_id,
    SUM(payment_sequential IS NULL) AS null_payment_sequential,
    SUM(payment_type IS NULL) AS null_payment_type,
    SUM(payment_installments IS NULL) AS null_installments,
    SUM(payment_value IS NULL) AS null_payment_value
FROM order_payments;


-- =====================================================
-- CHECK 15: PAYMENT VALUE VALIDATION
-- Identify invalid payment amounts and installments
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(payment_value < 0) AS negative_payments,
    SUM(payment_value = 0) AS zero_payments,
    SUM(payment_installments < 0) AS negative_installments,
    SUM(payment_installments = 0) AS zero_installments,
    SUM(TRIM(payment_type) = '') AS empty_payment_type,
    MIN(payment_value) AS min_payment,
    MAX(payment_value) AS max_payment,
    MIN(payment_installments) AS min_installments,
    MAX(payment_installments) AS max_installments
FROM order_payments;


-- =====================================================
-- CHECK 16: ZERO PAYMENT AND INSTALLMENT DETAILS
-- Investigate payments with zero amounts or installments
-- =====================================================

SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM order_payments
WHERE payment_value = 0
    OR payment_installments = 0
ORDER BY payment_type, order_id, payment_sequential;


-- =====================================================
-- CHECK 17: MISSING VALUES - ORDER REVIEWS
-- Identify NULL values in review attributes
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(review_id IS NULL) AS null_review_id,
    SUM(order_id IS NULL) AS null_order_id,
    SUM(review_score IS NULL) AS null_review_score,
    SUM(review_comment_title IS NULL) AS null_comment_title,
    SUM(review_comment_message IS NULL) AS null_comment_message,
    SUM(review_creation_date IS NULL) AS null_creation_date,
    SUM(review_answer_timestamp IS NULL) AS null_answer_date
FROM order_reviews;


-- =====================================================
-- CHECK 18: REVIEW SCORE VALIDATION
-- Validate review scores and examine their distribution
-- =====================================================

SELECT
    review_score,
    COUNT(*) AS total_reviews,
    ROUND(
        100.0 * COUNT(*) / (SELECT COUNT(*) FROM order_reviews),
        2
    ) AS percentage
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;


-- =====================================================
-- CHECK 19: MISSING VALUES - SELLERS
-- Identify NULL values in seller attributes
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(seller_id IS NULL) AS null_seller_id,
    SUM(seller_zip_code_prefix IS NULL) AS null_zip_code,
    SUM(seller_city IS NULL) AS null_city,
    SUM(seller_state IS NULL) AS null_state
FROM sellers;


-- =====================================================
-- CHECK 20: MISSING VALUES - GEOLOCATION
-- Identify NULL values in geographic attributes
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(geolocation_zip_code_prefix IS NULL) AS null_zip_code,
    SUM(geolocation_lat IS NULL) AS null_latitude,
    SUM(geolocation_lng IS NULL) AS null_longitude,
    SUM(geolocation_city IS NULL) AS null_city,
    SUM(geolocation_state IS NULL) AS null_state
FROM geolocation;


-- =====================================================
-- CHECK 21: GEOLOCATION COORDINATE VALIDATION
-- Identify invalid or potentially suspicious coordinates
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(geolocation_lat NOT BETWEEN -90 AND 90) AS invalid_latitude,
    SUM(geolocation_lng NOT BETWEEN -180 AND 180) AS invalid_longitude,
    SUM(geolocation_lat = 0 AND geolocation_lng = 0) AS zero_coordinates,
    MIN(geolocation_lat) AS min_latitude,
    MAX(geolocation_lat) AS max_latitude,
    MIN(geolocation_lng) AS min_longitude,
    MAX(geolocation_lng) AS max_longitude
FROM geolocation;


-- =====================================================
-- CHECK 22: GEOLOCATION OUTLIERS - BRAZIL BOUNDS
-- Identify coordinates outside approximate Brazil bounds
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(
        geolocation_lat NOT BETWEEN -34 AND 6
        OR geolocation_lng NOT BETWEEN -74 AND -34
    ) AS outside_brazil_bounds,
    ROUND(
        100.0 * SUM(
            geolocation_lat NOT BETWEEN -34 AND 6
            OR geolocation_lng NOT BETWEEN -74 AND -34
        ) / COUNT(*),
        2
    ) AS outside_brazil_percentage
FROM geolocation;


-- =====================================================
-- CHECK 23: GEOLOCATION OUTLIER DETAILS
-- Inspect coordinates outside approximate Brazil bounds
-- =====================================================

SELECT
    geolocation_zip_code_prefix,
    geolocation_city,
    geolocation_state,
    geolocation_lat,
    geolocation_lng
FROM geolocation
WHERE geolocation_lat NOT BETWEEN -34 AND 6
    OR geolocation_lng NOT BETWEEN -74 AND -34
ORDER BY geolocation_state, geolocation_city;


-- =====================================================
-- CHECK 24: GEOLOCATION ZIP CODE DUPLICATES
-- Identify repeated ZIP codes and potential join risks
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS unique_zip_codes,
    COUNT(*) - COUNT(DISTINCT geolocation_zip_code_prefix) AS additional_zip_records,
    (
        SELECT COUNT(*)
        FROM (
            SELECT geolocation_zip_code_prefix
            FROM geolocation
            GROUP BY geolocation_zip_code_prefix
            HAVING COUNT(*) > 1
        ) AS repeated_zips
    ) AS zip_codes_with_multiple_records
FROM geolocation;


-- =====================================================
-- CHECK 25: MISSING VALUES - CATEGORY TRANSLATION
-- Identify NULL values in product category translations
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(product_category_name IS NULL) AS null_category_name,
    SUM(product_category_name_english IS NULL) AS null_english_translation
FROM product_category_translation;


-- =====================================================
-- CHECK 26: MISSING PRODUCT CATEGORY TRANSLATIONS
-- Identify product categories without English translations
-- =====================================================

SELECT
    p.product_category_name,
    COUNT(*) AS affected_products
FROM products p
LEFT JOIN product_category_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
    AND t.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY affected_products DESC;


-- =====================================================
-- CHECK 27: ORDERS WITHOUT ORDER ITEMS
-- Identify orders with no associated products
-- =====================================================

SELECT
    o.order_status,
    COUNT(*) AS orders_without_items
FROM orders o
LEFT JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL
GROUP BY o.order_status
ORDER BY orders_without_items DESC;


-- =====================================================
-- CHECK 28: ORDERS WITHOUT PAYMENTS
-- Identify orders with no associated payment records
-- =====================================================

SELECT
    o.order_status,
    COUNT(*) AS orders_without_payments
FROM orders o
LEFT JOIN order_payments op
    ON o.order_id = op.order_id
WHERE op.order_id IS NULL
GROUP BY o.order_status
ORDER BY orders_without_payments DESC;


-- =====================================================
-- CHECK 29: ORDER WITHOUT PAYMENT DETAILS
-- Inspect the delivered order with no payment record
-- =====================================================

SELECT
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    COUNT(oi.order_item_id) AS total_items,
    ROUND(SUM(oi.price), 2) AS total_product_value,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_value,
    ROUND(
        SUM(oi.price + oi.freight_value),
        2
    ) AS total_order_value
FROM orders o
LEFT JOIN order_payments op
    ON o.order_id = op.order_id
LEFT JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE op.order_id IS NULL
GROUP BY
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date;


-- =====================================================
-- CHECK 30: ORDER ITEMS WITHOUT MATCHING PRODUCTS
-- Identify order items referencing missing products
-- =====================================================

SELECT
    COUNT(*) AS total_order_items,
    SUM(p.product_id IS NULL) AS items_without_product,
    COUNT(DISTINCT CASE
        WHEN p.product_id IS NULL THEN oi.product_id
    END) AS missing_product_ids
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id;


-- =====================================================
-- CHECK 31: ORDER ITEMS WITHOUT MATCHING SELLERS
-- Identify order items referencing missing sellers
-- =====================================================

SELECT
    COUNT(*) AS total_order_items,
    SUM(s.seller_id IS NULL) AS items_without_seller,
    COUNT(DISTINCT CASE
        WHEN s.seller_id IS NULL THEN oi.seller_id
    END) AS missing_seller_ids
FROM order_items oi
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id;


-- =====================================================
-- CHECK 32: ORDER VALUE VS PAYMENT RECONCILIATION
-- Compare order totals with recorded payment amounts
-- =====================================================

WITH item_totals AS (
    SELECT
        order_id,
        ROUND(SUM(price + freight_value), 2) AS order_value
    FROM order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        ROUND(SUM(payment_value), 2) AS payment_value
    FROM order_payments
    GROUP BY order_id
)
SELECT
    COUNT(*) AS orders_with_items_and_payments,
    SUM(ABS(i.order_value - p.payment_value) <= 0.01)
        AS matching_orders,
    SUM(ABS(i.order_value - p.payment_value) > 0.01)
        AS mismatched_orders,
    ROUND(
        100.0 * SUM(ABS(i.order_value - p.payment_value) > 0.01)
        / COUNT(*),
        2
    ) AS mismatch_percentage,
    ROUND(MAX(ABS(i.order_value - p.payment_value)), 2)
        AS max_absolute_difference
FROM item_totals i
INNER JOIN payment_totals p
    ON i.order_id = p.order_id;


-- =====================================================
-- CHECK 33: PAYMENT RECONCILIATION DIFFERENCE DETAILS
-- Inspect orders with the largest payment discrepancies
-- =====================================================

WITH item_totals AS (
    SELECT
        order_id,
        ROUND(SUM(price + freight_value), 2) AS order_value
    FROM order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        ROUND(SUM(payment_value), 2) AS payment_value
    FROM order_payments
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.order_status,
    i.order_value,
    p.payment_value,
    ROUND(p.payment_value - i.order_value, 2)
        AS payment_difference
FROM orders o
INNER JOIN item_totals i
    ON o.order_id = i.order_id
INNER JOIN payment_totals p
    ON o.order_id = p.order_id
WHERE ABS(p.payment_value - i.order_value) > 0.01
ORDER BY ABS(p.payment_value - i.order_value) DESC
LIMIT 10;


-- =====================================================
-- CHECK 34: PAYMENT DISCREPANCY DIRECTION
-- Classify orders by payment difference direction
-- =====================================================

WITH item_totals AS (
    SELECT
        order_id,
        ROUND(SUM(price + freight_value), 2) AS order_value
    FROM order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        ROUND(SUM(payment_value), 2) AS payment_value
    FROM order_payments
    GROUP BY order_id
),
order_differences AS (
    SELECT
        i.order_id,
        ROUND(p.payment_value - i.order_value, 2)
            AS payment_difference
    FROM item_totals i
    INNER JOIN payment_totals p
        ON i.order_id = p.order_id
)
SELECT
    CASE
        WHEN payment_difference > 0.01
            THEN 'Payment Higher'
        WHEN payment_difference < -0.01
            THEN 'Payment Lower'
    END AS discrepancy_type,
    COUNT(*) AS affected_orders,
    ROUND(SUM(payment_difference), 2)
        AS total_difference
FROM order_differences
WHERE ABS(payment_difference) > 0.01
GROUP BY discrepancy_type
ORDER BY affected_orders DESC;


-- =====================================================
-- CHECK 35: ORDER TIMESTAMP CONSISTENCY
-- Identify chronological inconsistencies in order dates
-- =====================================================

SELECT
    COUNT(*) AS total_orders,
    SUM(
        order_approved_at < order_purchase_timestamp
    ) AS approved_before_purchase,
    SUM(
        order_delivered_carrier_date < order_purchase_timestamp
    ) AS carrier_before_purchase,
    SUM(
        order_delivered_customer_date < order_purchase_timestamp
    ) AS delivered_before_purchase,
    SUM(
        order_delivered_customer_date < order_delivered_carrier_date
    ) AS delivered_before_carrier,
    SUM(
        order_delivered_customer_date > order_estimated_delivery_date
    ) AS delivered_after_estimate
FROM orders;


-- =====================================================
-- CHECK 36: CARRIER DATE BEFORE PURCHASE DETAILS
-- Inspect the largest chronological discrepancies
-- =====================================================

SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_delivered_carrier_date,
    TIMESTAMPDIFF(
        MINUTE,
        order_delivered_carrier_date,
        order_purchase_timestamp
    ) AS minutes_before_purchase
FROM orders
WHERE order_delivered_carrier_date < order_purchase_timestamp
ORDER BY minutes_before_purchase DESC
LIMIT 10;


-- =====================================================
-- CHECK 37: CARRIER TIMESTAMP ANOMALY DISTRIBUTION
-- Group chronological discrepancies by severity
-- =====================================================

WITH carrier_anomalies AS (
    SELECT
        order_id,
        TIMESTAMPDIFF(
            SECOND,
            order_delivered_carrier_date,
            order_purchase_timestamp
        ) AS difference_seconds
    FROM orders
    WHERE order_delivered_carrier_date < order_purchase_timestamp
)
SELECT
    CASE
        WHEN difference_seconds <= 3600
            THEN 'Up to 1 Hour'
        WHEN difference_seconds <= 10800
            THEN '1 to 3 Hours'
        WHEN difference_seconds <= 86400
            THEN '3 to 24 Hours'
        ELSE 'More Than 24 Hours'
    END AS anomaly_severity,
    COUNT(*) AS affected_orders
FROM carrier_anomalies
GROUP BY anomaly_severity
ORDER BY
    CASE anomaly_severity
        WHEN 'Up to 1 Hour' THEN 1
        WHEN '1 to 3 Hours' THEN 2
        WHEN '3 to 24 Hours' THEN 3
        ELSE 4
    END;


-- =====================================================
-- CHECK 38: DELIVERY BEFORE CARRIER DETAILS
-- Inspect orders delivered before carrier handoff
-- =====================================================

SELECT
    order_id,
    order_status,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    TIMESTAMPDIFF(
        MINUTE,
        order_delivered_customer_date,
        order_delivered_carrier_date
    ) AS minutes_before_carrier
FROM orders
WHERE order_delivered_customer_date < order_delivered_carrier_date
ORDER BY minutes_before_carrier DESC;


-- =====================================================
-- CHECK 39: LATE DELIVERY RATE
-- Measure late deliveries among completed orders
-- =====================================================

SELECT
    COUNT(*) AS delivered_orders,
    SUM(
        order_delivered_customer_date IS NOT NULL
    ) AS deliveries_with_valid_date,
    SUM(
        order_delivered_customer_date > order_estimated_delivery_date
    ) AS late_deliveries,
    ROUND(
        100.0 * SUM(
            order_delivered_customer_date > order_estimated_delivery_date
        ) / NULLIF(
            SUM(order_delivered_customer_date IS NOT NULL),
            0
        ),
        2
    ) AS late_delivery_percentage
FROM orders
WHERE order_status = 'delivered';