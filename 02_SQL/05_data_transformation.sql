
-- =====================================================
-- E-COMMERCE CUSTOMER & REVENUE ANALYTICS
-- 05: DATA TRANSFORMATION
-- =====================================================

USE olist_ecommerce;

-- =====================================================
-- TRANSFORMATION 1: ORDER-LEVEL ITEM AGGREGATION
-- Aggregate product and freight values per order
-- =====================================================

SELECT
    order_id,
    COUNT(*) AS total_items,
    COUNT(DISTINCT product_id) AS unique_products,
    ROUND(SUM(price), 2) AS product_revenue,
    ROUND(SUM(freight_value), 2) AS freight_revenue,
    ROUND(SUM(price + freight_value), 2) AS total_order_value
FROM order_items
GROUP BY order_id
ORDER BY total_order_value DESC
LIMIT 10;


-- =====================================================
-- TRANSFORMATION 2: ORDER-LEVEL PAYMENT AGGREGATION
-- Aggregate payment values and transactions per order
-- =====================================================

SELECT
    order_id,
    COUNT(*) AS payment_transactions,
    COUNT(DISTINCT payment_type) AS payment_methods,
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM order_payments
GROUP BY order_id
ORDER BY total_payment_value DESC
LIMIT 10;


-- =====================================================
-- TRANSFORMATION 3: ORDER-LEVEL REVENUE DATASET
-- Combine order details with aggregated item and
-- payment values without duplicating financial metrics
-- =====================================================

WITH item_summary AS (
    SELECT
        order_id,
        COUNT(*) AS total_items,
        COUNT(DISTINCT product_id) AS unique_products,
        ROUND(SUM(price), 2) AS product_revenue,
        ROUND(SUM(freight_value), 2) AS freight_revenue,
        ROUND(SUM(price + freight_value), 2) AS total_order_value
    FROM order_items
    GROUP BY order_id
),
payment_summary AS (
    SELECT
        order_id,
        COUNT(*) AS payment_transactions,
        COUNT(DISTINCT payment_type) AS payment_methods,
        ROUND(SUM(payment_value), 2) AS total_payment_value
    FROM order_payments
    GROUP BY order_id
)

SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    i.total_items,
    i.unique_products,
    i.product_revenue,
    i.freight_revenue,
    i.total_order_value,
    p.payment_transactions,
    p.payment_methods,
    p.total_payment_value
FROM orders AS o
LEFT JOIN item_summary AS i
    ON o.order_id = i.order_id
LEFT JOIN payment_summary AS p
    ON o.order_id = p.order_id
ORDER BY i.total_order_value DESC
LIMIT 10;


-- =====================================================
-- VALIDATION 1: ORDER-LEVEL DATASET UNIQUENESS
-- Verify that aggregated joins preserve one row
-- per order without introducing duplicate records
-- =====================================================

WITH item_summary AS (
    SELECT
        order_id,
        SUM(price) AS product_revenue,
        SUM(freight_value) AS freight_revenue
    FROM order_items
    GROUP BY order_id
),
payment_summary AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment_value
    FROM order_payments
    GROUP BY order_id
),
order_level_dataset AS (
    SELECT
        o.order_id,
        i.product_revenue,
        i.freight_revenue,
        p.total_payment_value
    FROM orders AS o
    LEFT JOIN item_summary AS i
        ON o.order_id = i.order_id
    LEFT JOIN payment_summary AS p
        ON o.order_id = p.order_id
)

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_rows
FROM order_level_dataset;


-- =====================================================
-- REVENUE KPI 1: TOTAL PRODUCT REVENUE
-- Calculate product revenue from delivered orders,
-- excluding freight charges and canceled orders
-- =====================================================

SELECT
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(SUM(oi.price), 2) AS total_product_revenue
FROM orders AS o
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';


-- =====================================================
-- REVENUE KPI 2: AVERAGE ORDER VALUE (AOV)
-- Calculate average product revenue per delivered order
-- excluding freight charges
-- =====================================================

SELECT
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(SUM(oi.price), 2) AS total_product_revenue,
    ROUND(
        SUM(oi.price) / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value
FROM orders AS o
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';


-- =====================================================
-- REVENUE KPI 3: FREIGHT AND TOTAL ORDER VALUE
-- Calculate product value, freight charges, and
-- combined order value for delivered orders
-- =====================================================

SELECT
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(SUM(oi.price), 2) AS total_product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_value,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_order_value,
    ROUND(
        100.0 * SUM(oi.freight_value)
        / NULLIF(SUM(oi.price + oi.freight_value), 0),
        2
    ) AS freight_share_pct
FROM orders AS o
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';


-- =====================================================
-- REVENUE KPI 4: AVERAGE FREIGHT PER ORDER
-- Calculate average freight charges per delivered
-- order and the average total order value
-- =====================================================

SELECT
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(
        SUM(oi.freight_value) / COUNT(DISTINCT o.order_id),
        2
    ) AS avg_freight_per_order,
    ROUND(
        SUM(oi.price + oi.freight_value)
        / COUNT(DISTINCT o.order_id),
        2
    ) AS avg_total_order_value
FROM orders AS o
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';


-- =====================================================
-- REVENUE KPI 5: MONTHLY REVENUE TREND
-- Analyze monthly product revenue and order volume
-- based on purchase date for delivered orders
-- =====================================================

SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS freight_value,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_order_value
FROM orders AS o
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
ORDER BY order_month;


-- =====================================================
-- REVENUE KPI 6: MONTH-OVER-MONTH REVENUE GROWTH
-- Compare monthly product revenue against the
-- previous calendar month using the LAG() function
-- =====================================================

WITH monthly_revenue AS (
    SELECT
        CAST(
            DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01')
            AS DATE
        ) AS order_month,
        ROUND(SUM(oi.price), 2) AS product_revenue
    FROM orders AS o
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        CAST(
            DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01')
            AS DATE
        )
),
revenue_comparison AS (
    SELECT
        order_month,
        product_revenue,
        LAG(order_month) OVER (
            ORDER BY order_month
        ) AS previous_month,
        LAG(product_revenue) OVER (
            ORDER BY order_month
        ) AS previous_month_revenue
    FROM monthly_revenue
)

SELECT
    DATE_FORMAT(order_month, '%Y-%m') AS order_month,
    product_revenue,
    previous_month_revenue,
    CASE
        WHEN previous_month IS NULL
          OR TIMESTAMPDIFF(MONTH, previous_month, order_month) <> 1
          OR previous_month_revenue = 0
        THEN NULL
        ELSE ROUND(
            100.0 * (product_revenue - previous_month_revenue)
            / previous_month_revenue,
            2
        )
    END AS mom_revenue_growth_pct
FROM revenue_comparison
ORDER BY order_month;


-- =====================================================
-- REVENUE KPI 7: YEAR-OVER-YEAR REVENUE GROWTH
-- Compare monthly product revenue against the
-- same calendar month in the previous year
-- =====================================================

WITH monthly_revenue AS (
    SELECT
        YEAR(o.order_purchase_timestamp) AS order_year,
        MONTH(o.order_purchase_timestamp) AS order_month,
        ROUND(SUM(oi.price), 2) AS product_revenue
    FROM orders AS o
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp)
)

SELECT
    current_year.order_year,
    current_year.order_month,
    current_year.product_revenue AS current_year_revenue,
    previous_year.product_revenue AS previous_year_revenue,
    ROUND(
        100.0 * (
            current_year.product_revenue
            - previous_year.product_revenue
        ) / NULLIF(previous_year.product_revenue, 0),
        2
    ) AS yoy_revenue_growth_pct
FROM monthly_revenue AS current_year
INNER JOIN monthly_revenue AS previous_year
    ON current_year.order_month = previous_year.order_month
    AND current_year.order_year = previous_year.order_year + 1
WHERE current_year.order_year = 2018
ORDER BY current_year.order_month;


-- =====================================================
-- REVENUE KPI 8: YEAR-TO-DATE REVENUE COMPARISON
-- Compare January-August product revenue across
-- 2017 and 2018 using equivalent calendar periods
-- =====================================================

WITH yearly_revenue AS (
    SELECT
        YEAR(o.order_purchase_timestamp) AS order_year,
        COUNT(DISTINCT o.order_id) AS delivered_orders,
        ROUND(SUM(oi.price), 2) AS product_revenue
    FROM orders AS o
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND YEAR(o.order_purchase_timestamp) IN (2017, 2018)
      AND MONTH(o.order_purchase_timestamp) BETWEEN 1 AND 8
    GROUP BY YEAR(o.order_purchase_timestamp)
)

SELECT
    current_year.delivered_orders AS orders_2018,
    previous_year.delivered_orders AS orders_2017,
    current_year.product_revenue AS revenue_2018,
    previous_year.product_revenue AS revenue_2017,
    ROUND(
        100.0 * (
            current_year.product_revenue
            - previous_year.product_revenue
        ) / NULLIF(previous_year.product_revenue, 0),
        2
    ) AS revenue_yoy_growth_pct,
    ROUND(
        100.0 * (
            current_year.delivered_orders
            - previous_year.delivered_orders
        ) / NULLIF(previous_year.delivered_orders, 0),
        2
    ) AS orders_yoy_growth_pct
FROM yearly_revenue AS current_year
INNER JOIN yearly_revenue AS previous_year
    ON current_year.order_year = previous_year.order_year + 1
WHERE current_year.order_year = 2018;


-- =====================================================
-- REVENUE KPI 9: YEAR-OVER-YEAR AOV COMPARISON
-- Compare average product value per delivered order
-- for January-August 2017 and 2018
-- =====================================================

SELECT
    YEAR(o.order_purchase_timestamp) AS order_year,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(
        SUM(oi.price) / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value
FROM orders AS o
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND YEAR(o.order_purchase_timestamp) IN (2017, 2018)
  AND MONTH(o.order_purchase_timestamp) BETWEEN 1 AND 8
GROUP BY YEAR(o.order_purchase_timestamp)
ORDER BY order_year;


-- =====================================================
-- REVENUE KPI 10: AOV YEAR-OVER-YEAR GROWTH
-- Measure the percentage change in average product
-- value per delivered order between equivalent periods
-- =====================================================

WITH yearly_aov AS (
    SELECT
        YEAR(o.order_purchase_timestamp) AS order_year,
        SUM(oi.price) / COUNT(DISTINCT o.order_id) AS average_order_value
    FROM orders AS o
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND YEAR(o.order_purchase_timestamp) IN (2017, 2018)
      AND MONTH(o.order_purchase_timestamp) BETWEEN 1 AND 8
    GROUP BY YEAR(o.order_purchase_timestamp)
)

SELECT
    ROUND(current_year.average_order_value, 2) AS aov_2018,
    ROUND(previous_year.average_order_value, 2) AS aov_2017,
    ROUND(
        100.0 * (
            current_year.average_order_value
            - previous_year.average_order_value
        ) / NULLIF(previous_year.average_order_value, 0),
        2
    ) AS aov_yoy_growth_pct
FROM yearly_aov AS current_year
INNER JOIN yearly_aov AS previous_year
    ON current_year.order_year = previous_year.order_year + 1
WHERE current_year.order_year = 2018;


-- =====================================================
-- PRODUCT KPI 1: REVENUE BY PRODUCT CATEGORY
-- Identify the highest-revenue product categories
-- based on delivered orders, excluding freight charges
-- =====================================================

SELECT
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown Category'
    ) AS product_category,
    COUNT(*) AS items_sold,
    COUNT(DISTINCT oi.order_id) AS delivered_orders,
    ROUND(SUM(oi.price), 2) AS product_revenue
FROM order_items AS oi
INNER JOIN orders AS o
    ON oi.order_id = o.order_id
INNER JOIN products AS p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_translation AS pct
    ON p.product_category_name = pct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown Category'
    )
ORDER BY product_revenue DESC
LIMIT 10;


-- =====================================================
-- PRODUCT KPI 2: AVERAGE SELLING PRICE BY CATEGORY
-- Compare product revenue, sales volume, and average
-- unit selling price across product categories
-- =====================================================

SELECT
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown Category'
    ) AS product_category,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(AVG(oi.price), 2) AS avg_selling_price
FROM order_items AS oi
INNER JOIN orders AS o
    ON oi.order_id = o.order_id
INNER JOIN products AS p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_translation AS pct
    ON p.product_category_name = pct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown Category'
    )
ORDER BY product_revenue DESC
LIMIT 10;


-- =====================================================
-- PRODUCT KPI 3: REVENUE CONTRIBUTION BY CATEGORY
-- Calculate each product category's percentage share
-- of total delivered-order product revenue
-- =====================================================

WITH category_revenue AS (
    SELECT
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown Category'
        ) AS product_category,
        SUM(oi.price) AS product_revenue
    FROM order_items AS oi
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN products AS p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation AS pct
        ON p.product_category_name = pct.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown Category'
        )
)

SELECT
    product_category,
    ROUND(product_revenue, 2) AS product_revenue,
    ROUND(
        100.0 * product_revenue
        / SUM(product_revenue) OVER (),
        2
    ) AS revenue_share_pct
FROM category_revenue
ORDER BY product_revenue DESC
LIMIT 10;


-- =====================================================
-- PRODUCT KPI 4: TOP 10 REVENUE CONCENTRATION
-- Measure the combined revenue contribution of the
-- ten highest-performing product categories
-- =====================================================

WITH category_revenue AS (
    SELECT
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown Category'
        ) AS product_category,
        SUM(oi.price) AS product_revenue
    FROM order_items AS oi
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN products AS p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation AS pct
        ON p.product_category_name = pct.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown Category'
        )
),
ranked_categories AS (
    SELECT
        product_category,
        product_revenue,
        ROW_NUMBER() OVER (
            ORDER BY product_revenue DESC, product_category
        ) AS revenue_rank
    FROM category_revenue
)

SELECT
    ROUND(SUM(product_revenue), 2) AS total_product_revenue,
    ROUND(
        SUM(
            CASE
                WHEN revenue_rank <= 10 THEN product_revenue
                ELSE 0
            END
        ),
        2
    ) AS top_10_revenue,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN revenue_rank <= 10 THEN product_revenue
                ELSE 0
            END
        ) / NULLIF(SUM(product_revenue), 0),
        2
    ) AS top_10_revenue_share_pct
FROM ranked_categories;


-- =====================================================
-- PRODUCT KPI 5: TOP 10 PRODUCTS BY REVENUE
-- Identify individual products generating the highest
-- product revenue from delivered orders
-- =====================================================

SELECT
    oi.product_id,
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown Category'
    ) AS product_category,
    COUNT(*) AS units_sold,
    COUNT(DISTINCT oi.order_id) AS delivered_orders,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(AVG(oi.price), 2) AS avg_selling_price
FROM order_items AS oi
INNER JOIN orders AS o
    ON oi.order_id = o.order_id
INNER JOIN products AS p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_translation AS pct
    ON p.product_category_name = pct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    oi.product_id,
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown Category'
    )
ORDER BY product_revenue DESC
LIMIT 10;


-- =====================================================
-- PRODUCT KPI 6: TOP 10 PRODUCTS BY UNITS SOLD
-- Identify the highest-volume products and compare
-- their sales quantities with generated revenue
-- =====================================================

SELECT
    oi.product_id,
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown Category'
    ) AS product_category,
    COUNT(*) AS units_sold,
    COUNT(DISTINCT oi.order_id) AS delivered_orders,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(AVG(oi.price), 2) AS avg_selling_price
FROM order_items AS oi
INNER JOIN orders AS o
    ON oi.order_id = o.order_id
INNER JOIN products AS p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_translation AS pct
    ON p.product_category_name = pct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    oi.product_id,
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown Category'
    )
ORDER BY units_sold DESC, product_revenue DESC
LIMIT 10;


-- =====================================================
-- PRODUCT KPI 7: TOP 10 PRODUCT REVENUE CONCENTRATION
-- Measure the percentage of total product revenue
-- generated by the ten highest-revenue products
-- =====================================================

WITH product_revenue AS (
    SELECT
        oi.product_id,
        SUM(oi.price) AS revenue
    FROM order_items AS oi
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.product_id
),
ranked_products AS (
    SELECT
        product_id,
        revenue,
        ROW_NUMBER() OVER (
            ORDER BY revenue DESC, product_id
        ) AS revenue_rank
    FROM product_revenue
)

SELECT
    COUNT(*) AS total_products_sold,
    ROUND(SUM(revenue), 2) AS total_product_revenue,
    ROUND(
        SUM(
            CASE
                WHEN revenue_rank <= 10 THEN revenue
                ELSE 0
            END
        ),
        2
    ) AS top_10_products_revenue,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN revenue_rank <= 10 THEN revenue
                ELSE 0
            END
        ) / NULLIF(SUM(revenue), 0),
        2
    ) AS top_10_revenue_share_pct
FROM ranked_products;


-- =====================================================
-- PRODUCT KPI 8: SALES PERFORMANCE BY PRICE SEGMENT
-- Segment sold items by their recorded selling price
-- and compare sales volume with product revenue
-- =====================================================

WITH price_segments AS (
    SELECT
        oi.price,
        CASE
            WHEN oi.price < 50 THEN '1. Budget'
            WHEN oi.price < 100 THEN '2. Lower Mid-Range'
            WHEN oi.price < 200 THEN '3. Mid-Range'
            WHEN oi.price < 500 THEN '4. Premium'
            ELSE '5. Luxury'
        END AS price_segment
    FROM order_items AS oi
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
)

SELECT
    price_segment,
    COUNT(*) AS units_sold,
    ROUND(SUM(price), 2) AS product_revenue,
    ROUND(AVG(price), 2) AS avg_selling_price,
    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS units_share_pct,
    ROUND(
        100.0 * SUM(price) /
        SUM(SUM(price)) OVER (),
        2
    ) AS revenue_share_pct
FROM price_segments
GROUP BY price_segment
ORDER BY price_segment;


-- =====================================================
-- PRODUCT KPI 9: CATEGORY REVENUE GROWTH (2017 VS 2018)
-- Compare category revenue across equivalent periods
-- (January through August) to avoid partial-year bias
-- =====================================================

WITH category_yearly_revenue AS (
    SELECT
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown Category'
        ) AS product_category,
        YEAR(o.order_purchase_timestamp) AS order_year,
        SUM(oi.price) AS product_revenue
    FROM order_items AS oi
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN products AS p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation AS pct
        ON p.product_category_name = pct.product_category_name
    WHERE o.order_status = 'delivered'
      AND YEAR(o.order_purchase_timestamp) IN (2017, 2018)
      AND MONTH(o.order_purchase_timestamp) BETWEEN 1 AND 8
    GROUP BY
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown Category'
        ),
        YEAR(o.order_purchase_timestamp)
),
category_comparison AS (
    SELECT
        product_category,
        SUM(
            CASE WHEN order_year = 2017
                 THEN product_revenue ELSE 0 END
        ) AS revenue_2017,
        SUM(
            CASE WHEN order_year = 2018
                 THEN product_revenue ELSE 0 END
        ) AS revenue_2018
    FROM category_yearly_revenue
    GROUP BY product_category
)

SELECT
    product_category,
    ROUND(revenue_2017, 2) AS revenue_2017,
    ROUND(revenue_2018, 2) AS revenue_2018,
    ROUND(revenue_2018 - revenue_2017, 2) AS revenue_change,
    ROUND(
        100.0 * (revenue_2018 - revenue_2017)
        / NULLIF(revenue_2017, 0),
        2
    ) AS revenue_growth_pct
FROM category_comparison
ORDER BY revenue_2018 DESC
LIMIT 10;


-- =====================================================
-- PRODUCT KPI 10: CATEGORY CONTRIBUTION TO REVENUE GROWTH
-- Measure how much each category contributed to the
-- total revenue change between Jan-Aug 2017 and 2018
-- =====================================================

WITH category_revenue AS (
    SELECT
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown Category'
        ) AS product_category,
        YEAR(o.order_purchase_timestamp) AS order_year,
        SUM(oi.price) AS product_revenue
    FROM order_items AS oi
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN products AS p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation AS pct
        ON p.product_category_name = pct.product_category_name
    WHERE o.order_status = 'delivered'
      AND YEAR(o.order_purchase_timestamp) IN (2017, 2018)
      AND MONTH(o.order_purchase_timestamp) BETWEEN 1 AND 8
    GROUP BY
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown Category'
        ),
        YEAR(o.order_purchase_timestamp)
),
category_growth AS (
    SELECT
        product_category,
        SUM(
            CASE WHEN order_year = 2018
                 THEN product_revenue ELSE 0 END
        ) -
        SUM(
            CASE WHEN order_year = 2017
                 THEN product_revenue ELSE 0 END
        ) AS revenue_change
    FROM category_revenue
    GROUP BY product_category
)

SELECT
    product_category,
    ROUND(revenue_change, 2) AS revenue_change,
    ROUND(
        100.0 * revenue_change
        / NULLIF(SUM(revenue_change) OVER (), 0),
        2
    ) AS growth_contribution_pct
FROM category_growth
ORDER BY revenue_change DESC
LIMIT 10;


-- =====================================================
-- PRODUCT KPI 11: CATEGORY REVENUE SHARE CHANGE
-- Compare each category's share of total product
-- revenue between Jan-Aug 2017 and Jan-Aug 2018
-- =====================================================

WITH category_yearly_revenue AS (
    SELECT
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown Category'
        ) AS product_category,
        YEAR(o.order_purchase_timestamp) AS order_year,
        SUM(oi.price) AS product_revenue
    FROM order_items AS oi
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN products AS p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation AS pct
        ON p.product_category_name = pct.product_category_name
    WHERE o.order_status = 'delivered'
      AND YEAR(o.order_purchase_timestamp) IN (2017, 2018)
      AND MONTH(o.order_purchase_timestamp) BETWEEN 1 AND 8
    GROUP BY
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown Category'
        ),
        YEAR(o.order_purchase_timestamp)
),
category_market_share AS (
    SELECT
        product_category,
        order_year,
        product_revenue,
        100.0 * product_revenue
        / NULLIF(
            SUM(product_revenue) OVER (
                PARTITION BY order_year
            ),
            0
        ) AS revenue_share_pct
    FROM category_yearly_revenue
)

SELECT
    product_category,
    ROUND(
        MAX(
            CASE WHEN order_year = 2017
                 THEN revenue_share_pct END
        ),
        2
    ) AS revenue_share_2017_pct,
    ROUND(
        MAX(
            CASE WHEN order_year = 2018
                 THEN revenue_share_pct END
        ),
        2
    ) AS revenue_share_2018_pct,
    ROUND(
        COALESCE(
            MAX(
                CASE WHEN order_year = 2018
                     THEN revenue_share_pct END
            ),
            0
        ) -
        COALESCE(
            MAX(
                CASE WHEN order_year = 2017
                     THEN revenue_share_pct END
            ),
            0
        ),
        2
    ) AS share_change_pp
FROM category_market_share
GROUP BY product_category
ORDER BY share_change_pp DESC
LIMIT 10;


-- =====================================================
-- PRODUCT KPI 12: CATEGORIES LOSING REVENUE SHARE
-- Identify categories with the largest declines in
-- revenue share between Jan-Aug 2017 and 2018
-- =====================================================

WITH category_yearly_revenue AS (
    SELECT
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown Category'
        ) AS product_category,
        YEAR(o.order_purchase_timestamp) AS order_year,
        SUM(oi.price) AS product_revenue
    FROM order_items AS oi
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN products AS p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation AS pct
        ON p.product_category_name = pct.product_category_name
    WHERE o.order_status = 'delivered'
      AND YEAR(o.order_purchase_timestamp) IN (2017, 2018)
      AND MONTH(o.order_purchase_timestamp) BETWEEN 1 AND 8
    GROUP BY
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown Category'
        ),
        YEAR(o.order_purchase_timestamp)
),
category_share AS (
    SELECT
        product_category,
        order_year,
        product_revenue,
        100.0 * product_revenue
        / NULLIF(
            SUM(product_revenue) OVER (
                PARTITION BY order_year
            ),
            0
        ) AS revenue_share_pct
    FROM category_yearly_revenue
),
category_comparison AS (
    SELECT
        product_category,
        MAX(
            CASE WHEN order_year = 2017
                 THEN revenue_share_pct END
        ) AS share_2017,
        MAX(
            CASE WHEN order_year = 2018
                 THEN revenue_share_pct END
        ) AS share_2018,
        SUM(
            CASE WHEN order_year = 2017
                 THEN product_revenue ELSE 0 END
        ) AS revenue_2017,
        SUM(
            CASE WHEN order_year = 2018
                 THEN product_revenue ELSE 0 END
        ) AS revenue_2018
    FROM category_share
    GROUP BY product_category
)

SELECT
    product_category,
    ROUND(COALESCE(share_2017, 0), 2) AS share_2017_pct,
    ROUND(COALESCE(share_2018, 0), 2) AS share_2018_pct,
    ROUND(
        COALESCE(share_2018, 0)
        - COALESCE(share_2017, 0),
        2
    ) AS share_change_pp,
    ROUND(
        100.0 * (revenue_2018 - revenue_2017)
        / NULLIF(revenue_2017, 0),
        2
    ) AS revenue_growth_pct
FROM category_comparison
ORDER BY share_change_pp ASC
LIMIT 10;


-- =====================================================
-- PRODUCT KPI 13: CATEGORY GROWTH DRIVERS
-- Compare unit sales growth and average selling price
-- changes across equivalent periods in 2017 and 2018
-- =====================================================

WITH category_yearly_metrics AS (
    SELECT
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown Category'
        ) AS product_category,
        YEAR(o.order_purchase_timestamp) AS order_year,
        COUNT(*) AS units_sold,
        AVG(oi.price) AS avg_selling_price,
        SUM(oi.price) AS product_revenue
    FROM order_items AS oi
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN products AS p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation AS pct
        ON p.product_category_name = pct.product_category_name
    WHERE o.order_status = 'delivered'
      AND YEAR(o.order_purchase_timestamp) IN (2017, 2018)
      AND MONTH(o.order_purchase_timestamp) BETWEEN 1 AND 8
    GROUP BY
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown Category'
        ),
        YEAR(o.order_purchase_timestamp)
),
category_comparison AS (
    SELECT
        product_category,
        MAX(CASE WHEN order_year = 2017
                 THEN units_sold END) AS units_2017,
        MAX(CASE WHEN order_year = 2018
                 THEN units_sold END) AS units_2018,
        MAX(CASE WHEN order_year = 2017
                 THEN avg_selling_price END) AS avg_price_2017,
        MAX(CASE WHEN order_year = 2018
                 THEN avg_selling_price END) AS avg_price_2018,
        MAX(CASE WHEN order_year = 2018
                 THEN product_revenue END) AS revenue_2018
    FROM category_yearly_metrics
    GROUP BY product_category
)

SELECT
    product_category,
    units_2017,
    units_2018,
    ROUND(
        100.0 * (units_2018 - units_2017)
        / NULLIF(units_2017, 0),
        2
    ) AS units_growth_pct,
    ROUND(avg_price_2017, 2) AS avg_price_2017,
    ROUND(avg_price_2018, 2) AS avg_price_2018,
    ROUND(
        100.0 * (avg_price_2018 - avg_price_2017)
        / NULLIF(avg_price_2017, 0),
        2
    ) AS avg_price_change_pct
FROM category_comparison
WHERE units_2017 IS NOT NULL
  AND units_2018 IS NOT NULL
ORDER BY revenue_2018 DESC
LIMIT 10;


-- =====================================================
-- CUSTOMER KPI 1: UNIQUE CUSTOMERS & REPEAT PURCHASE RATE
-- Identify distinct customers and measure the share
-- who placed more than one delivered order
-- =====================================================

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS delivered_orders
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    COUNT(*) AS unique_customers,
    SUM(delivered_orders) AS total_delivered_orders,
    SUM(
        CASE WHEN delivered_orders = 1
             THEN 1 ELSE 0 END
    ) AS one_time_customers,
    SUM(
        CASE WHEN delivered_orders > 1
             THEN 1 ELSE 0 END
    ) AS repeat_customers,
    ROUND(
        100.0 * SUM(
            CASE WHEN delivered_orders > 1
                 THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_purchase_rate_pct
FROM customer_orders;


-- =====================================================
-- CUSTOMER KPI 2: PURCHASE FREQUENCY DISTRIBUTION
-- Analyze how many delivered orders each customer
-- placed during the observed dataset period
-- =====================================================

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS delivered_orders
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    delivered_orders AS purchase_frequency,
    COUNT(*) AS customer_count,
    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct
FROM customer_orders
GROUP BY delivered_orders
ORDER BY purchase_frequency;


-- =====================================================
-- CUSTOMER KPI 3: REVENUE BY CUSTOMER TYPE
-- Compare one-time and repeat customers based on
-- delivered orders and product revenue contribution
-- =====================================================

WITH order_revenue AS (
    SELECT
        oi.order_id,
        SUM(oi.price) AS product_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
customer_metrics AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS delivered_orders,
        SUM(COALESCE(r.product_revenue, 0)) AS product_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    LEFT JOIN order_revenue AS r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_segments AS (
    SELECT
        CASE
            WHEN delivered_orders = 1 THEN 'One-Time'
            ELSE 'Repeat'
        END AS customer_type,
        delivered_orders,
        product_revenue
    FROM customer_metrics
)

SELECT
    customer_type,
    COUNT(*) AS customers,
    SUM(delivered_orders) AS delivered_orders,
    ROUND(SUM(product_revenue), 2) AS product_revenue,
    ROUND(
        100.0 * SUM(product_revenue)
        / NULLIF(SUM(SUM(product_revenue)) OVER (), 0),
        2
    ) AS revenue_share_pct,
    ROUND(AVG(product_revenue), 2) AS avg_revenue_per_customer
FROM customer_segments
GROUP BY customer_type
ORDER BY product_revenue DESC;


-- =====================================================
-- CUSTOMER KPI 4: AOV BY CUSTOMER TYPE
-- Compare average product revenue per delivered order
-- between one-time and repeat customers
-- =====================================================

WITH order_revenue AS (
    SELECT
        oi.order_id,
        SUM(oi.price) AS product_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS delivered_orders
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_order_values AS (
    SELECT
        CASE
            WHEN co.delivered_orders = 1 THEN 'One-Time'
            ELSE 'Repeat'
        END AS customer_type,
        o.order_id,
        COALESCE(r.product_revenue, 0) AS product_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN customer_orders AS co
        ON c.customer_unique_id = co.customer_unique_id
    LEFT JOIN order_revenue AS r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
)

SELECT
    customer_type,
    COUNT(*) AS delivered_orders,
    ROUND(SUM(product_revenue), 2) AS product_revenue,
    ROUND(AVG(product_revenue), 2) AS avg_order_value
FROM customer_order_values
GROUP BY customer_type
ORDER BY avg_order_value DESC;


-- =====================================================
-- CUSTOMER KPI 5: FIRST VS SUBSEQUENT ORDER VALUE
-- Compare the first delivered order with later
-- delivered orders among repeat customers
-- =====================================================

WITH order_revenue AS (
    SELECT
        oi.order_id,
        SUM(oi.price) AS product_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
ranked_customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        COALESCE(r.product_revenue, 0) AS product_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS order_sequence,
        COUNT(*) OVER (
            PARTITION BY c.customer_unique_id
        ) AS customer_order_count
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    LEFT JOIN order_revenue AS r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
)

SELECT
    CASE
        WHEN order_sequence = 1 THEN 'First Order'
        ELSE 'Subsequent Orders'
    END AS order_type,
    COUNT(*) AS delivered_orders,
    ROUND(SUM(product_revenue), 2) AS product_revenue,
    ROUND(AVG(product_revenue), 2) AS avg_order_value
FROM ranked_customer_orders
WHERE customer_order_count > 1
GROUP BY
    CASE
        WHEN order_sequence = 1 THEN 'First Order'
        ELSE 'Subsequent Orders'
    END
ORDER BY
    CASE
        WHEN order_type = 'First Order' THEN 1
        ELSE 2
    END;


-- =====================================================
-- CUSTOMER KPI 6: TIME TO SECOND PURCHASE
-- Measure the time between the first and second
-- delivered-order purchases for repeat customers
-- =====================================================

WITH ranked_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS order_sequence
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
first_second_orders AS (
    SELECT
        customer_unique_id,
        MIN(
            CASE WHEN order_sequence = 1
                 THEN order_purchase_timestamp END
        ) AS first_purchase,
        MIN(
            CASE WHEN order_sequence = 2
                 THEN order_purchase_timestamp END
        ) AS second_purchase
    FROM ranked_orders
    WHERE order_sequence <= 2
    GROUP BY customer_unique_id
)

SELECT
    COUNT(*) AS repeat_customers,
    ROUND(
        AVG(
            TIMESTAMPDIFF(
                HOUR,
                first_purchase,
                second_purchase
            ) / 24.0
        ),
        2
    ) AS avg_days_to_second_purchase,
    ROUND(
        MIN(
            TIMESTAMPDIFF(
                HOUR,
                first_purchase,
                second_purchase
            ) / 24.0
        ),
        2
    ) AS min_days,
    ROUND(
        MAX(
            TIMESTAMPDIFF(
                HOUR,
                first_purchase,
                second_purchase
            ) / 24.0
        ),
        2
    ) AS max_days
FROM first_second_orders
WHERE second_purchase IS NOT NULL;


-- =====================================================
-- CUSTOMER KPI 7: MEDIAN TIME TO SECOND PURCHASE
-- Calculate the median number of days between the
-- first and second delivered-order purchases
-- =====================================================

WITH ranked_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS order_sequence
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
purchase_intervals AS (
    SELECT
        customer_unique_id,
        TIMESTAMPDIFF(
            SECOND,
            MIN(CASE WHEN order_sequence = 1
                     THEN order_purchase_timestamp END),
            MIN(CASE WHEN order_sequence = 2
                     THEN order_purchase_timestamp END)
        ) / 86400.0 AS days_to_second_purchase
    FROM ranked_orders
    WHERE order_sequence <= 2
    GROUP BY customer_unique_id
    HAVING COUNT(*) = 2
),
ordered_intervals AS (
    SELECT
        days_to_second_purchase,
        ROW_NUMBER() OVER (
            ORDER BY days_to_second_purchase
        ) AS row_num,
        COUNT(*) OVER () AS total_customers
    FROM purchase_intervals
)

SELECT
    COUNT(*) AS repeat_customers,
    ROUND(AVG(days_to_second_purchase), 2)
        AS median_days_to_second_purchase
FROM ordered_intervals
WHERE row_num IN (
    FLOOR((total_customers + 1) / 2),
    FLOOR((total_customers + 2) / 2)
);


-- =====================================================
-- CUSTOMER KPI 8: SECOND PURCHASE TIMING DISTRIBUTION
-- Segment repeat customers by the number of days
-- between their first and second delivered purchases
-- =====================================================

WITH ranked_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS order_sequence
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
purchase_intervals AS (
    SELECT
        customer_unique_id,
        TIMESTAMPDIFF(
            SECOND,
            MIN(CASE WHEN order_sequence = 1
                     THEN order_purchase_timestamp END),
            MIN(CASE WHEN order_sequence = 2
                     THEN order_purchase_timestamp END)
        ) / 86400.0 AS days_to_second_purchase
    FROM ranked_orders
    WHERE order_sequence <= 2
    GROUP BY customer_unique_id
    HAVING COUNT(*) = 2
),
timing_segments AS (
    SELECT
        CASE
            WHEN days_to_second_purchase < 7
                THEN 'Within 7 Days'
            WHEN days_to_second_purchase < 30
                THEN '7-30 Days'
            WHEN days_to_second_purchase < 60
                THEN '30-60 Days'
            WHEN days_to_second_purchase < 90
                THEN '60-90 Days'
            WHEN days_to_second_purchase < 180
                THEN '90-180 Days'
            ELSE '180+ Days'
        END AS timing_segment,
        CASE
            WHEN days_to_second_purchase < 7 THEN 1
            WHEN days_to_second_purchase < 30 THEN 2
            WHEN days_to_second_purchase < 60 THEN 3
            WHEN days_to_second_purchase < 90 THEN 4
            WHEN days_to_second_purchase < 180 THEN 5
            ELSE 6
        END AS segment_order
    FROM purchase_intervals
)

SELECT
    timing_segment,
    COUNT(*) AS repeat_customers,
    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct
FROM timing_segments
GROUP BY timing_segment, segment_order
ORDER BY segment_order;


-- =====================================================
-- CUSTOMER KPI 9: VERY EARLY REPEAT PURCHASES
-- Investigate how frequently customers place their
-- second delivered-order purchase within 24 hours
-- =====================================================

WITH ranked_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS order_sequence
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
purchase_intervals AS (
    SELECT
        customer_unique_id,
        TIMESTAMPDIFF(
            SECOND,
            MIN(CASE WHEN order_sequence = 1
                     THEN order_purchase_timestamp END),
            MIN(CASE WHEN order_sequence = 2
                     THEN order_purchase_timestamp END)
        ) AS seconds_to_second_purchase
    FROM ranked_orders
    WHERE order_sequence <= 2
    GROUP BY customer_unique_id
    HAVING COUNT(*) = 2
)

SELECT
    COUNT(*) AS repeat_customers,
    SUM(
        CASE WHEN seconds_to_second_purchase < 3600
             THEN 1 ELSE 0 END
    ) AS within_1_hour,
    SUM(
        CASE WHEN seconds_to_second_purchase < 86400
             THEN 1 ELSE 0 END
    ) AS within_24_hours,
    SUM(
        CASE WHEN seconds_to_second_purchase < 604800
             THEN 1 ELSE 0 END
    ) AS within_7_days,
    ROUND(
        100.0 * SUM(
            CASE WHEN seconds_to_second_purchase < 86400
                 THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS within_24_hours_pct
FROM purchase_intervals;


-- =====================================================
-- CUSTOMER KPI 10: 24-HOUR-SEPARATED REPEAT PURCHASE RATE
-- Identify customers with at least two delivered orders
-- placed at least 24 hours apart
-- =====================================================

WITH customer_purchase_activity AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS delivered_orders,
        MIN(o.order_purchase_timestamp) AS first_purchase,
        MAX(o.order_purchase_timestamp) AS last_purchase
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    COUNT(*) AS unique_customers,
    SUM(
        CASE WHEN delivered_orders > 1
             THEN 1 ELSE 0 END
    ) AS repeat_customers,
    SUM(
        CASE
            WHEN delivered_orders > 1
             AND TIMESTAMPDIFF(
                 SECOND,
                 first_purchase,
                 last_purchase
             ) >= 86400
            THEN 1 ELSE 0
        END
    ) AS repeat_customers_24h_apart,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN delivered_orders > 1
                 AND TIMESTAMPDIFF(
                     SECOND,
                     first_purchase,
                     last_purchase
                 ) >= 86400
                THEN 1 ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_purchase_rate_24h_pct
FROM customer_purchase_activity;


-- =====================================================
-- CUSTOMER KPI 11: 30-DAY REPEAT RATE BY ACQUISITION MONTH
-- Measure repeat purchasing within 30 days of the
-- first delivered-order purchase for eligible cohorts
-- =====================================================

WITH delivered_purchases AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
ranked_purchases AS (
    SELECT
        customer_unique_id,
        order_id,
        order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp, order_id
        ) AS purchase_sequence
    FROM delivered_purchases
),
customer_first_purchase AS (
    SELECT
        customer_unique_id,
        MIN(order_purchase_timestamp) AS first_purchase
    FROM delivered_purchases
    GROUP BY customer_unique_id
),
customer_30_day_activity AS (
    SELECT
        f.customer_unique_id,
        DATE_FORMAT(f.first_purchase, '%Y-%m') AS acquisition_month,
        MAX(
            CASE
                WHEN r.purchase_sequence > 1
                 AND r.order_purchase_timestamp
                     <= DATE_ADD(f.first_purchase, INTERVAL 30 DAY)
                THEN 1 ELSE 0
            END
        ) AS repeated_within_30_days
    FROM customer_first_purchase AS f
    INNER JOIN ranked_purchases AS r
        ON f.customer_unique_id = r.customer_unique_id
    WHERE f.first_purchase <= (
        SELECT DATE_SUB(
            MAX(order_purchase_timestamp),
            INTERVAL 30 DAY
        )
        FROM delivered_purchases
    )
    GROUP BY
        f.customer_unique_id,
        DATE_FORMAT(f.first_purchase, '%Y-%m')
)

SELECT
    acquisition_month,
    COUNT(*) AS eligible_customers,
    SUM(repeated_within_30_days) AS repeat_customers_30d,
    ROUND(
        100.0 * SUM(repeated_within_30_days)
        / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_purchase_rate_30d_pct
FROM customer_30_day_activity
GROUP BY acquisition_month
ORDER BY acquisition_month;


-- =====================================================
-- CUSTOMER KPI 12: YOY 30-DAY REPEAT PURCHASE RATE
-- Compare January-July acquisition cohorts in 2017
-- and 2018 using a consistent 30-day observation window
-- =====================================================

WITH delivered_purchases AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
customer_first_purchase AS (
    SELECT
        customer_unique_id,
        MIN(order_purchase_timestamp) AS first_purchase
    FROM delivered_purchases
    GROUP BY customer_unique_id
),
customer_repeat_activity AS (
    SELECT
        f.customer_unique_id,
        YEAR(f.first_purchase) AS acquisition_year,
        MAX(
            CASE
                WHEN p.order_purchase_timestamp > f.first_purchase
                 AND p.order_purchase_timestamp
                     <= DATE_ADD(f.first_purchase, INTERVAL 30 DAY)
                THEN 1 ELSE 0
            END
        ) AS repeated_within_30_days
    FROM customer_first_purchase AS f
    INNER JOIN delivered_purchases AS p
        ON f.customer_unique_id = p.customer_unique_id
    WHERE YEAR(f.first_purchase) IN (2017, 2018)
      AND MONTH(f.first_purchase) BETWEEN 1 AND 7
      AND f.first_purchase <= (
          SELECT DATE_SUB(
              MAX(order_purchase_timestamp),
              INTERVAL 30 DAY
          )
          FROM delivered_purchases
      )
    GROUP BY
        f.customer_unique_id,
        YEAR(f.first_purchase)
)

SELECT
    acquisition_year,
    COUNT(*) AS eligible_customers,
    SUM(repeated_within_30_days) AS repeat_customers_30d,
    ROUND(
        100.0 * SUM(repeated_within_30_days)
        / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_purchase_rate_30d_pct
FROM customer_repeat_activity
GROUP BY acquisition_year
ORDER BY acquisition_year;


-- =====================================================
-- CUSTOMER KPI 13: YOY 30-DAY REPEAT RATE (24H SEPARATION)
-- Compare January-July acquisition cohorts using
-- a consistent 30-day observation window and requiring
-- at least 24 hours between delivered-order purchases
-- =====================================================

WITH delivered_purchases AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
customer_first_purchase AS (
    SELECT
        customer_unique_id,
        MIN(order_purchase_timestamp) AS first_purchase
    FROM delivered_purchases
    GROUP BY customer_unique_id
),
customer_repeat_activity AS (
    SELECT
        f.customer_unique_id,
        YEAR(f.first_purchase) AS acquisition_year,
        MAX(
            CASE
                WHEN p.order_purchase_timestamp >=
                     DATE_ADD(f.first_purchase, INTERVAL 24 HOUR)
                 AND p.order_purchase_timestamp <=
                     DATE_ADD(f.first_purchase, INTERVAL 30 DAY)
                THEN 1 ELSE 0
            END
        ) AS repeated_within_30_days_24h
    FROM customer_first_purchase AS f
    INNER JOIN delivered_purchases AS p
        ON f.customer_unique_id = p.customer_unique_id
    WHERE YEAR(f.first_purchase) IN (2017, 2018)
      AND MONTH(f.first_purchase) BETWEEN 1 AND 7
      AND f.first_purchase <= (
          SELECT DATE_SUB(
              MAX(order_purchase_timestamp),
              INTERVAL 30 DAY
          )
          FROM delivered_purchases
      )
    GROUP BY
        f.customer_unique_id,
        YEAR(f.first_purchase)
)

SELECT
    acquisition_year,
    COUNT(*) AS eligible_customers,
    SUM(repeated_within_30_days_24h)
        AS repeat_customers_30d_24h,
    ROUND(
        100.0 * SUM(repeated_within_30_days_24h)
        / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_purchase_rate_30d_24h_pct
FROM customer_repeat_activity
GROUP BY acquisition_year
ORDER BY acquisition_year;


-- =====================================================
-- CUSTOMER KPI 14: YOY REPEAT RATE SIGNIFICANCE TEST
-- Two-proportion z-test using a MySQL-compatible
-- approximation of the two-sided p-value
-- =====================================================

WITH cohort_counts AS (
    SELECT
        2017 AS acquisition_year,
        17344 AS customers,
        113 AS repeat_customers
    UNION ALL
    SELECT
        2018,
        44377,
        277
),
comparison AS (
    SELECT
        MAX(CASE WHEN acquisition_year = 2017
            THEN customers END) AS n_2017,
        MAX(CASE WHEN acquisition_year = 2018
            THEN customers END) AS n_2018,
        MAX(CASE WHEN acquisition_year = 2017
            THEN repeat_customers END) AS x_2017,
        MAX(CASE WHEN acquisition_year = 2018
            THEN repeat_customers END) AS x_2018
    FROM cohort_counts
),
rates AS (
    SELECT
        x_2017 * 1.0 / n_2017 AS p_2017,
        x_2018 * 1.0 / n_2018 AS p_2018,
        (x_2017 + x_2018) * 1.0
            / (n_2017 + n_2018) AS pooled_rate,
        n_2017,
        n_2018
    FROM comparison
),
z_test AS (
    SELECT
        p_2017,
        p_2018,
        (p_2018 - p_2017) * 100 AS difference_pp,
        (p_2018 - p_2017) /
        SQRT(
            pooled_rate * (1 - pooled_rate)
            * (1.0 / n_2017 + 1.0 / n_2018)
        ) AS z_score
    FROM rates
),
normal_approximation AS (
    SELECT
        p_2017,
        p_2018,
        difference_pp,
        z_score,
        ABS(z_score) AS z,
        1.0 / (1.0 + 0.2316419 * ABS(z_score)) AS t
    FROM z_test
),
p_value_calculation AS (
    SELECT
        p_2017,
        p_2018,
        difference_pp,
        z_score,
        2 * (
            EXP(-z * z / 2.0) / SQRT(2.0 * PI())
            * (
                0.319381530 * t
                - 0.356563782 * POW(t, 2)
                + 1.781477937 * POW(t, 3)
                - 1.821255978 * POW(t, 4)
                + 1.330274429 * POW(t, 5)
            )
        ) AS p_value
    FROM normal_approximation
)

SELECT
    ROUND(p_2017 * 100, 4) AS rate_2017_pct,
    ROUND(p_2018 * 100, 4) AS rate_2018_pct,
    ROUND(difference_pp, 4) AS difference_percentage_points,
    ROUND(z_score, 4) AS z_score,
    ROUND(p_value, 4) AS p_value,
    CASE
        WHEN p_value < 0.05
            THEN 'Statistically Significant'
        ELSE 'Not Statistically Significant'
    END AS significance_result
FROM p_value_calculation;


-- =====================================================
-- CUSTOMER KPI 15: ANNUAL REVENUE BY CUSTOMER TYPE
-- Compare product revenue from one-time and repeat
-- customers using full-period customer classification
-- =====================================================

WITH customer_order_frequency AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS delivered_order_count
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
delivered_order_revenue AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        YEAR(o.order_purchase_timestamp) AS purchase_year,
        SUM(oi.price) AS product_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND YEAR(o.order_purchase_timestamp) IN (2017, 2018)
      AND MONTH(o.order_purchase_timestamp) BETWEEN 1 AND 7
    GROUP BY
        o.order_id,
        c.customer_unique_id,
        YEAR(o.order_purchase_timestamp)
),
customer_revenue AS (
    SELECT
        r.purchase_year,
        CASE
            WHEN f.delivered_order_count >= 2
                THEN 'Repeat Customer'
            ELSE 'One-Time Customer'
        END AS customer_type,
        COUNT(*) AS delivered_orders,
        COUNT(DISTINCT r.customer_unique_id) AS customers,
        SUM(r.product_revenue) AS product_revenue
    FROM delivered_order_revenue AS r
    INNER JOIN customer_order_frequency AS f
        ON r.customer_unique_id = f.customer_unique_id
    GROUP BY
        r.purchase_year,
        customer_type
)

SELECT
    purchase_year,
    customer_type,
    customers,
    delivered_orders,
    ROUND(product_revenue, 2) AS product_revenue,
    ROUND(
        100.0 * product_revenue
        / SUM(product_revenue) OVER (
            PARTITION BY purchase_year
        ),
        2
    ) AS annual_revenue_share_pct
FROM customer_revenue
ORDER BY
    purchase_year,
    customer_type;


-- =====================================================
-- CUSTOMER KPI 16: FIRST VS SUBSEQUENT PURCHASE REVENUE
-- Measure revenue generated by first and subsequent
-- delivered orders across comparable annual periods
-- =====================================================

WITH ranked_delivered_orders AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp,
        YEAR(o.order_purchase_timestamp) AS purchase_year,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS purchase_sequence
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
order_revenue AS (
    SELECT
        oi.order_id,
        SUM(oi.price) AS product_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
classified_orders AS (
    SELECT
        r.purchase_year,
        CASE
            WHEN r.purchase_sequence = 1
                THEN 'First Purchase'
            ELSE 'Subsequent Purchase'
        END AS purchase_type,
        r.order_id,
        r.customer_unique_id,
        v.product_revenue
    FROM ranked_delivered_orders AS r
    INNER JOIN order_revenue AS v
        ON r.order_id = v.order_id
    WHERE r.purchase_year IN (2017, 2018)
      AND MONTH(r.order_purchase_timestamp) BETWEEN 1 AND 7
),
annual_revenue AS (
    SELECT
        purchase_year,
        purchase_type,
        COUNT(*) AS delivered_orders,
        COUNT(DISTINCT customer_unique_id) AS customers,
        SUM(product_revenue) AS product_revenue
    FROM classified_orders
    GROUP BY
        purchase_year,
        purchase_type
)

SELECT
    purchase_year,
    purchase_type,
    customers,
    delivered_orders,
    ROUND(product_revenue, 2) AS product_revenue,
    ROUND(
        100.0 * product_revenue
        / SUM(product_revenue) OVER (
            PARTITION BY purchase_year
        ),
        2
    ) AS annual_revenue_share_pct
FROM annual_revenue
ORDER BY
    purchase_year,
    purchase_type;


-- =====================================================
-- CUSTOMER KPI 17: AOV BY PURCHASE SEQUENCE AND YEAR
-- Compare first-purchase and subsequent-purchase
-- average order values across January-July periods
-- =====================================================

WITH ranked_delivered_orders AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp,
        YEAR(o.order_purchase_timestamp) AS purchase_year,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS purchase_sequence
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
order_revenue AS (
    SELECT
        oi.order_id,
        SUM(oi.price) AS product_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
classified_orders AS (
    SELECT
        r.purchase_year,
        CASE
            WHEN r.purchase_sequence = 1
                THEN 'First Purchase'
            ELSE 'Subsequent Purchase'
        END AS purchase_type,
        r.order_id,
        v.product_revenue
    FROM ranked_delivered_orders AS r
    INNER JOIN order_revenue AS v
        ON r.order_id = v.order_id
    WHERE r.purchase_year IN (2017, 2018)
      AND MONTH(r.order_purchase_timestamp) BETWEEN 1 AND 7
)

SELECT
    purchase_year,
    purchase_type,
    COUNT(*) AS delivered_orders,
    ROUND(SUM(product_revenue), 2) AS product_revenue,
    ROUND(AVG(product_revenue), 2) AS average_order_value
FROM classified_orders
GROUP BY
    purchase_year,
    purchase_type
ORDER BY
    purchase_year,
    purchase_type;


-- =====================================================
-- CUSTOMER KPI 18: HISTORICAL CUSTOMER REVENUE
-- Measure observed product revenue per unique customer
-- and compare one-time versus repeat customers
-- =====================================================

WITH delivered_order_revenue AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        SUM(oi.price) AS product_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id,
        o.order_id
),
customer_revenue AS (
    SELECT
        customer_unique_id,
        COUNT(*) AS delivered_orders,
        SUM(product_revenue) AS historical_revenue
    FROM delivered_order_revenue
    GROUP BY customer_unique_id
),
ranked_customers AS (
    SELECT
        CASE
            WHEN delivered_orders = 1
                THEN 'One-Time Customer'
            ELSE 'Repeat Customer'
        END AS customer_type,
        historical_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY
                CASE
                    WHEN delivered_orders = 1
                        THEN 'One-Time Customer'
                    ELSE 'Repeat Customer'
                END
            ORDER BY historical_revenue
        ) AS revenue_rank,
        COUNT(*) OVER (
            PARTITION BY
                CASE
                    WHEN delivered_orders = 1
                        THEN 'One-Time Customer'
                    ELSE 'Repeat Customer'
                END
        ) AS group_size
    FROM customer_revenue
)

SELECT
    customer_type,
    COUNT(*) AS customers,
    ROUND(AVG(historical_revenue), 2)
        AS avg_historical_revenue,
    ROUND(
        AVG(
            CASE
                WHEN revenue_rank IN (
                    FLOOR((group_size + 1) / 2),
                    FLOOR((group_size + 2) / 2)
                )
                THEN historical_revenue
            END
        ),
        2
    ) AS median_historical_revenue,
    ROUND(MAX(historical_revenue), 2)
        AS max_historical_revenue
FROM ranked_customers
GROUP BY customer_type
ORDER BY customer_type;


-- =====================================================
-- CUSTOMER KPI 19: REVENUE CONCENTRATION BY PERCENTILE
-- Measure the share of historical product revenue
-- generated by the highest-spending customer segments
-- =====================================================

WITH customer_revenue AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price) AS historical_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
ranked_customers AS (
    SELECT
        customer_unique_id,
        historical_revenue,
        ROW_NUMBER() OVER (
            ORDER BY historical_revenue DESC, customer_unique_id
        ) AS revenue_rank,
        COUNT(*) OVER () AS total_customers,
        SUM(historical_revenue) OVER () AS total_revenue
    FROM customer_revenue
),
percentile_segments AS (
    SELECT 1 AS top_percent
    UNION ALL SELECT 5
    UNION ALL SELECT 10
    UNION ALL SELECT 20
)

SELECT
    CONCAT('Top ', p.top_percent, '%') AS customer_segment,
    COUNT(*) AS customers,
    ROUND(SUM(r.historical_revenue), 2) AS product_revenue,
    ROUND(
        100.0 * SUM(r.historical_revenue)
        / MAX(r.total_revenue),
        2
    ) AS revenue_share_pct
FROM percentile_segments AS p
INNER JOIN ranked_customers AS r
    ON r.revenue_rank <= CEIL(
        r.total_customers * p.top_percent / 100.0
    )
GROUP BY p.top_percent
ORDER BY p.top_percent;


-- =====================================================
-- CUSTOMER KPI 20: RFM BASE METRICS
-- Calculate recency, frequency, and monetary value
-- per unique customer using delivered orders
-- =====================================================

WITH analysis_date AS (
    SELECT
        DATE_ADD(
            DATE(MAX(order_purchase_timestamp)),
            INTERVAL 1 DAY
        ) AS snapshot_date
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_order_revenue AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        SUM(oi.price) AS product_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
),
customer_rfm AS (
    SELECT
        customer_unique_id,
        MAX(order_purchase_timestamp) AS last_purchase,
        COUNT(*) AS frequency,
        SUM(product_revenue) AS monetary
    FROM delivered_order_revenue
    GROUP BY customer_unique_id
)

SELECT
    COUNT(*) AS total_customers,
    MIN(DATEDIFF(a.snapshot_date, r.last_purchase))
        AS min_recency_days,
    ROUND(
        AVG(DATEDIFF(a.snapshot_date, r.last_purchase)),
        2
    ) AS avg_recency_days,
    MAX(DATEDIFF(a.snapshot_date, r.last_purchase))
        AS max_recency_days,
    ROUND(AVG(r.frequency), 2)
        AS avg_order_frequency,
    MAX(r.frequency) AS max_order_frequency,
    ROUND(AVG(r.monetary), 2)
        AS avg_monetary_value,
    ROUND(MAX(r.monetary), 2)
        AS max_monetary_value
FROM customer_rfm AS r
CROSS JOIN analysis_date AS a;


-- =====================================================
-- CUSTOMER KPI 21: RFM SCORE DISTRIBUTION
-- Assign recency, frequency, and monetary scores
-- while preserving equal scores for tied values
-- =====================================================

WITH analysis_date AS (
    SELECT
        DATE_ADD(
            DATE(MAX(order_purchase_timestamp)),
            INTERVAL 1 DAY
        ) AS snapshot_date
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_order_revenue AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        SUM(oi.price) AS product_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
),
customer_rfm AS (
    SELECT
        customer_unique_id,
        MAX(order_purchase_timestamp) AS last_purchase,
        COUNT(*) AS frequency,
        SUM(product_revenue) AS monetary
    FROM delivered_order_revenue
    GROUP BY customer_unique_id
),
rfm_metrics AS (
    SELECT
        r.customer_unique_id,
        DATEDIFF(a.snapshot_date, r.last_purchase)
            AS recency_days,
        r.frequency,
        r.monetary
    FROM customer_rfm AS r
    CROSS JOIN analysis_date AS a
),
rfm_percentiles AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        CUME_DIST() OVER (
            ORDER BY recency_days ASC
        ) AS recency_percentile,
        CUME_DIST() OVER (
            ORDER BY monetary ASC
        ) AS monetary_percentile
    FROM rfm_metrics
),
rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        6 - CEIL(recency_percentile * 5) AS r_score,
        LEAST(frequency, 5) AS f_score,
        CEIL(monetary_percentile * 5) AS m_score
    FROM rfm_percentiles
)

SELECT
    'Recency' AS dimension,
    r_score AS score,
    COUNT(*) AS customers,
    ROUND(100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (
            PARTITION BY 'Recency'
        ), 2) AS customer_share_pct
FROM rfm_scores
GROUP BY r_score

UNION ALL

SELECT
    'Frequency',
    f_score,
    COUNT(*),
    ROUND(100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (
            PARTITION BY 'Frequency'
        ), 2)
FROM rfm_scores
GROUP BY f_score

UNION ALL

SELECT
    'Monetary',
    m_score,
    COUNT(*),
    ROUND(100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (
            PARTITION BY 'Monetary'
        ), 2)
FROM rfm_scores
GROUP BY m_score

ORDER BY dimension, score;


-- =====================================================
-- CUSTOMER KPI 22: RULE-BASED RFM SEGMENTATION
-- Create actionable customer groups based on
-- recency, purchase frequency, and monetary value
-- =====================================================

WITH analysis_date AS (
    SELECT
        DATE_ADD(
            DATE(MAX(order_purchase_timestamp)),
            INTERVAL 1 DAY
        ) AS snapshot_date
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_order_revenue AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        SUM(oi.price) AS product_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
),
customer_rfm AS (
    SELECT
        customer_unique_id,
        MAX(order_purchase_timestamp) AS last_purchase,
        COUNT(*) AS frequency,
        SUM(product_revenue) AS monetary
    FROM delivered_order_revenue
    GROUP BY customer_unique_id
),
rfm_metrics AS (
    SELECT
        r.customer_unique_id,
        DATEDIFF(a.snapshot_date, r.last_purchase)
            AS recency_days,
        r.frequency,
        r.monetary
    FROM customer_rfm AS r
    CROSS JOIN analysis_date AS a
),
rfm_percentiles AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        CUME_DIST() OVER (
            ORDER BY recency_days ASC
        ) AS recency_percentile,
        CUME_DIST() OVER (
            ORDER BY monetary ASC
        ) AS monetary_percentile
    FROM rfm_metrics
),
rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        6 - CEIL(recency_percentile * 5) AS r_score,
        LEAST(frequency, 5) AS f_score,
        CEIL(monetary_percentile * 5) AS m_score
    FROM rfm_percentiles
),
customer_segments AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        CASE
            WHEN frequency >= 2
                 AND r_score >= 4
                 AND m_score >= 4
                THEN 'Champions'
            WHEN frequency >= 2
                 AND r_score >= 3
                THEN 'Loyal Customers'
            WHEN frequency >= 2
                THEN 'At-Risk Repeat'
            WHEN frequency = 1
                 AND m_score >= 4
                THEN 'High-Value One-Time'
            ELSE 'Other One-Time'
        END AS customer_segment
    FROM rfm_scores
)

SELECT
    customer_segment,
    COUNT(*) AS customers,
    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct,
    ROUND(SUM(monetary), 2) AS product_revenue,
    ROUND(
        100.0 * SUM(monetary)
        / SUM(SUM(monetary)) OVER (),
        2
    ) AS revenue_share_pct,
    ROUND(AVG(monetary), 2) AS avg_customer_revenue,
    ROUND(AVG(recency_days), 2) AS avg_recency_days
FROM customer_segments
GROUP BY customer_segment
ORDER BY product_revenue DESC;


-- =====================================================
-- CUSTOMER KPI 23: RFM SEGMENT VALIDATION
-- Verify customer coverage, segment uniqueness,
-- revenue reconciliation, and valid RFM scores
-- =====================================================

WITH analysis_date AS (
    SELECT
        DATE_ADD(
            DATE(MAX(order_purchase_timestamp)),
            INTERVAL 1 DAY
        ) AS snapshot_date
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_order_revenue AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        SUM(oi.price) AS product_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
),
customer_rfm AS (
    SELECT
        customer_unique_id,
        MAX(order_purchase_timestamp) AS last_purchase,
        COUNT(*) AS frequency,
        SUM(product_revenue) AS monetary
    FROM delivered_order_revenue
    GROUP BY customer_unique_id
),
rfm_metrics AS (
    SELECT
        r.customer_unique_id,
        DATEDIFF(a.snapshot_date, r.last_purchase)
            AS recency_days,
        r.frequency,
        r.monetary
    FROM customer_rfm AS r
    CROSS JOIN analysis_date AS a
),
rfm_percentiles AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        CUME_DIST() OVER (
            ORDER BY recency_days ASC
        ) AS recency_percentile,
        CUME_DIST() OVER (
            ORDER BY monetary ASC
        ) AS monetary_percentile
    FROM rfm_metrics
),
rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        6 - CEIL(recency_percentile * 5) AS r_score,
        LEAST(frequency, 5) AS f_score,
        CEIL(monetary_percentile * 5) AS m_score
    FROM rfm_percentiles
),
customer_segments AS (
    SELECT
        customer_unique_id,
        monetary,
        r_score,
        f_score,
        m_score,
        CASE
            WHEN frequency >= 2
                 AND r_score >= 4
                 AND m_score >= 4
                THEN 'Champions'
            WHEN frequency >= 2
                 AND r_score >= 3
                THEN 'Loyal Customers'
            WHEN frequency >= 2
                THEN 'At-Risk Repeat'
            WHEN frequency = 1
                 AND m_score >= 4
                THEN 'High-Value One-Time'
            ELSE 'Other One-Time'
        END AS customer_segment
    FROM rfm_scores
)

SELECT
    COUNT(*) AS segment_rows,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    COUNT(*) - COUNT(DISTINCT customer_unique_id)
        AS duplicate_customer_rows,
    SUM(
        CASE
            WHEN customer_segment IS NULL
              OR r_score NOT BETWEEN 1 AND 5
              OR f_score NOT BETWEEN 1 AND 5
              OR m_score NOT BETWEEN 1 AND 5
            THEN 1 ELSE 0
        END
    ) AS invalid_segment_or_score_rows,
    ROUND(SUM(monetary), 2)
        AS segmented_product_revenue,
    ROUND(
        SUM(monetary) - (
            SELECT SUM(price)
            FROM order_items AS oi
            INNER JOIN orders AS o
                ON oi.order_id = o.order_id
            WHERE o.order_status = 'delivered'
        ),
        2
    ) AS revenue_reconciliation_difference
FROM customer_segments;


-- =====================================================
-- CUSTOMER KPI 24: HIGH-VALUE ONE-TIME RECENCY PROFILE
-- Analyze purchase recency among high-value customers
-- with exactly one delivered order
-- =====================================================

WITH analysis_date AS (
    SELECT
        DATE_ADD(
            DATE(MAX(order_purchase_timestamp)),
            INTERVAL 1 DAY
        ) AS snapshot_date
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_order_revenue AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        SUM(oi.price) AS product_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
),
customer_rfm AS (
    SELECT
        customer_unique_id,
        MAX(order_purchase_timestamp) AS last_purchase,
        COUNT(*) AS frequency,
        SUM(product_revenue) AS monetary
    FROM delivered_order_revenue
    GROUP BY customer_unique_id
),
rfm_metrics AS (
    SELECT
        r.customer_unique_id,
        DATEDIFF(a.snapshot_date, r.last_purchase)
            AS recency_days,
        r.frequency,
        r.monetary
    FROM customer_rfm AS r
    CROSS JOIN analysis_date AS a
),
rfm_percentiles AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        CUME_DIST() OVER (
            ORDER BY monetary ASC
        ) AS monetary_percentile
    FROM rfm_metrics
),
high_value_one_time AS (
    SELECT
        customer_unique_id,
        recency_days,
        monetary
    FROM rfm_percentiles
    WHERE frequency = 1
      AND CEIL(monetary_percentile * 5) >= 4
),
recency_buckets AS (
    SELECT
        customer_unique_id,
        monetary,
        CASE
            WHEN recency_days <= 30 THEN '0-30 Days'
            WHEN recency_days <= 90 THEN '31-90 Days'
            WHEN recency_days <= 180 THEN '91-180 Days'
            WHEN recency_days <= 365 THEN '181-365 Days'
            ELSE '365+ Days'
        END AS recency_bucket,
        CASE
            WHEN recency_days <= 30 THEN 1
            WHEN recency_days <= 90 THEN 2
            WHEN recency_days <= 180 THEN 3
            WHEN recency_days <= 365 THEN 4
            ELSE 5
        END AS bucket_order
    FROM high_value_one_time
)

SELECT
    recency_bucket,
    COUNT(*) AS customers,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct,
    ROUND(SUM(monetary), 2) AS product_revenue,
    ROUND(
        100.0 * SUM(monetary)
        / SUM(SUM(monetary)) OVER (),
        2
    ) AS revenue_share_pct
FROM recency_buckets
GROUP BY recency_bucket, bucket_order
ORDER BY bucket_order;


-- =====================================================
-- CUSTOMER KPI 25: FIRST-ORDER VALUE VS REPEAT RATE
-- Compare 90-day repeat purchase rates across
-- first-order value quintiles with complete follow-up
-- =====================================================

WITH analysis_date AS (
    SELECT
        MAX(order_purchase_timestamp) AS last_observed_purchase
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_order_revenue AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        SUM(oi.price) AS product_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
),
ranked_orders AS (
    SELECT
        customer_unique_id,
        order_id,
        order_purchase_timestamp,
        product_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp, order_id
        ) AS purchase_number,
        MIN(order_purchase_timestamp) OVER (
            PARTITION BY customer_unique_id
        ) AS first_purchase_timestamp
    FROM delivered_order_revenue
),
eligible_customers AS (
    SELECT
        customer_unique_id,
        MAX(
            CASE
                WHEN purchase_number = 1
                THEN product_revenue
            END
        ) AS first_order_value,
        MAX(
            CASE
                WHEN purchase_number > 1
                 AND order_purchase_timestamp >
                     DATE_ADD(
                         first_purchase_timestamp,
                         INTERVAL 24 HOUR
                     )
                 AND order_purchase_timestamp <=
                     DATE_ADD(
                         first_purchase_timestamp,
                         INTERVAL 90 DAY
                     )
                THEN 1 ELSE 0
            END
        ) AS repeated_within_90_days
    FROM ranked_orders
    CROSS JOIN analysis_date
    WHERE first_purchase_timestamp <=
          DATE_SUB(
              last_observed_purchase,
              INTERVAL 90 DAY
          )
    GROUP BY customer_unique_id
),
value_percentiles AS (
    SELECT
        customer_unique_id,
        first_order_value,
        repeated_within_90_days,
        CUME_DIST() OVER (
            ORDER BY first_order_value
        ) AS value_percentile
    FROM eligible_customers
),
value_segments AS (
    SELECT
        customer_unique_id,
        first_order_value,
        repeated_within_90_days,
        LEAST(
            CEIL(value_percentile * 5),
            5
        ) AS first_order_value_score
    FROM value_percentiles
)

SELECT
    first_order_value_score,
    COUNT(*) AS eligible_customers,
    SUM(repeated_within_90_days)
        AS repeat_customers_90d,
    ROUND(
        100.0 * SUM(repeated_within_90_days)
        / COUNT(*),
        2
    ) AS repeat_rate_90d_pct,
    ROUND(AVG(first_order_value), 2)
        AS avg_first_order_value,
    ROUND(MIN(first_order_value), 2)
        AS min_first_order_value,
    ROUND(MAX(first_order_value), 2)
        AS max_first_order_value
FROM value_segments
GROUP BY first_order_value_score
ORDER BY first_order_value_score;


-- =====================================================
-- CUSTOMER KPI 26: CHI-SQUARE TEST OF INDEPENDENCE
-- Test the association between first-order value
-- quintiles and 90-day repeat purchase behavior
-- =====================================================

WITH analysis_date AS (
    SELECT
        MAX(order_purchase_timestamp) AS last_observed_purchase
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_order_revenue AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        SUM(oi.price) AS product_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
),
ranked_orders AS (
    SELECT
        customer_unique_id,
        order_id,
        order_purchase_timestamp,
        product_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp, order_id
        ) AS purchase_number,
        MIN(order_purchase_timestamp) OVER (
            PARTITION BY customer_unique_id
        ) AS first_purchase_timestamp
    FROM delivered_order_revenue
),
eligible_customers AS (
    SELECT
        customer_unique_id,
        MAX(
            CASE
                WHEN purchase_number = 1
                THEN product_revenue
            END
        ) AS first_order_value,
        MAX(
            CASE
                WHEN purchase_number > 1
                 AND order_purchase_timestamp >
                     DATE_ADD(
                         first_purchase_timestamp,
                         INTERVAL 24 HOUR
                     )
                 AND order_purchase_timestamp <=
                     DATE_ADD(
                         first_purchase_timestamp,
                         INTERVAL 90 DAY
                     )
                THEN 1 ELSE 0
            END
        ) AS repeated_within_90_days
    FROM ranked_orders
    CROSS JOIN analysis_date
    WHERE first_purchase_timestamp <=
          DATE_SUB(
              last_observed_purchase,
              INTERVAL 90 DAY
          )
    GROUP BY customer_unique_id
),
value_percentiles AS (
    SELECT
        customer_unique_id,
        repeated_within_90_days,
        CUME_DIST() OVER (
            ORDER BY first_order_value
        ) AS value_percentile
    FROM eligible_customers
),
value_segments AS (
    SELECT
        LEAST(
            CEIL(value_percentile * 5),
            5
        ) AS value_score,
        repeated_within_90_days
    FROM value_percentiles
),
observed_counts AS (
    SELECT
        value_score,
        COUNT(*) AS total_customers,
        SUM(repeated_within_90_days) AS repeat_customers,
        COUNT(*) - SUM(repeated_within_90_days)
            AS non_repeat_customers
    FROM value_segments
    GROUP BY value_score
),
overall_totals AS (
    SELECT
        SUM(total_customers) AS total_customers,
        SUM(repeat_customers) AS total_repeat_customers,
        SUM(non_repeat_customers)
            AS total_non_repeat_customers
    FROM observed_counts
),
expected_counts AS (
    SELECT
        o.value_score,
        o.repeat_customers,
        o.non_repeat_customers,
        o.total_customers * t.total_repeat_customers
            / t.total_customers AS expected_repeat,
        o.total_customers * t.total_non_repeat_customers
            / t.total_customers AS expected_non_repeat
    FROM observed_counts AS o
    CROSS JOIN overall_totals AS t
),
chi_square_result AS (
    SELECT
        SUM(
            POW(repeat_customers - expected_repeat, 2)
                / expected_repeat
            +
            POW(non_repeat_customers - expected_non_repeat, 2)
                / expected_non_repeat
        ) AS chi_square_statistic
    FROM expected_counts
)

SELECT
    ROUND(chi_square_statistic, 4)
        AS chi_square_statistic,
    4 AS degrees_of_freedom,
    ROUND(
        EXP(-chi_square_statistic / 2)
        * (1 + chi_square_statistic / 2),
        4
    ) AS p_value,
    CASE
        WHEN EXP(-chi_square_statistic / 2)
             * (1 + chi_square_statistic / 2) < 0.05
        THEN 'Statistically Significant'
        ELSE 'Not Statistically Significant'
    END AS significance_result
FROM chi_square_result;


-- =====================================================
-- CUSTOMER KPI 27: CRAMER'S V EFFECT SIZE
-- Quantify the strength of association between
-- first-order value groups and 90-day repeat behavior
-- =====================================================

WITH chi_square_input AS (
    SELECT
        3.0936 AS chi_square_statistic,
        14840 + 15237 + 15114 + 15046 + 15083
            AS eligible_customers,
        5 AS spending_groups,
        2 AS repeat_outcomes
),
effect_size AS (
    SELECT
        chi_square_statistic,
        eligible_customers,
        SQRT(
            chi_square_statistic /
            (
                eligible_customers *
                LEAST(
                    spending_groups - 1,
                    repeat_outcomes - 1
                )
            )
        ) AS cramers_v
    FROM chi_square_input
)

SELECT
    eligible_customers,
    chi_square_statistic,
    ROUND(cramers_v, 4) AS cramers_v,
    CASE
        WHEN cramers_v < 0.10 THEN 'Very Weak Association'
        WHEN cramers_v < 0.30 THEN 'Weak Association'
        WHEN cramers_v < 0.50 THEN 'Moderate Association'
        ELSE 'Strong Association'
    END AS association_strength
FROM effect_size;


-- =====================================================
-- CUSTOMER KPI 28: DELIVERY EXPERIENCE VS REPEAT RATE
-- Compare 90-day repeat purchase rates following
-- on-time and late first delivered orders
-- =====================================================

WITH analysis_date AS (
    SELECT
        MAX(order_purchase_timestamp) AS last_observed_purchase
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS purchase_number
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
first_orders AS (
    SELECT
        customer_unique_id,
        order_id,
        order_delivered_customer_date,
        CASE
            WHEN DATE(order_delivered_customer_date)
                 > DATE(order_estimated_delivery_date)
                THEN 'Late Delivery'
            ELSE 'On-Time Delivery'
        END AS delivery_performance
    FROM delivered_orders
    WHERE purchase_number = 1
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date
          >= order_purchase_timestamp
),
eligible_first_orders AS (
    SELECT
        f.customer_unique_id,
        f.order_delivered_customer_date,
        f.delivery_performance
    FROM first_orders AS f
    CROSS JOIN analysis_date AS a
    WHERE f.order_delivered_customer_date <=
          DATE_SUB(
              a.last_observed_purchase,
              INTERVAL 90 DAY
          )
),
customer_repeat_outcomes AS (
    SELECT
        f.customer_unique_id,
        f.delivery_performance,
        MAX(
            CASE
                WHEN d.purchase_number > 1
                 AND d.order_purchase_timestamp >
                     f.order_delivered_customer_date
                 AND d.order_purchase_timestamp <=
                     DATE_ADD(
                         f.order_delivered_customer_date,
                         INTERVAL 90 DAY
                     )
                THEN 1 ELSE 0
            END
        ) AS repeated_within_90_days
    FROM eligible_first_orders AS f
    INNER JOIN delivered_orders AS d
        ON f.customer_unique_id = d.customer_unique_id
    GROUP BY
        f.customer_unique_id,
        f.delivery_performance
)

SELECT
    delivery_performance,
    COUNT(*) AS eligible_customers,
    SUM(repeated_within_90_days)
        AS repeat_customers_90d,
    ROUND(
        100.0 * SUM(repeated_within_90_days)
        / COUNT(*),
        2
    ) AS repeat_rate_90d_pct
FROM customer_repeat_outcomes
GROUP BY delivery_performance
ORDER BY delivery_performance;


-- =====================================================
-- CUSTOMER KPI 29: DELIVERY EXPERIENCE Z-TEST
-- Test whether 90-day repeat purchase rates differ
-- between on-time and late first deliveries
-- =====================================================

WITH delivery_counts AS (
    SELECT
        67826 AS on_time_customers,
        787 AS on_time_repeat_customers,
        5217 AS late_customers,
        41 AS late_repeat_customers
),
conversion_rates AS (
    SELECT
        *,
        on_time_repeat_customers * 1.0
            / on_time_customers AS on_time_rate,
        late_repeat_customers * 1.0
            / late_customers AS late_rate,
        (on_time_repeat_customers + late_repeat_customers)
            * 1.0 / (on_time_customers + late_customers)
            AS pooled_rate
    FROM delivery_counts
),
z_test AS (
    SELECT
        *,
        (on_time_rate - late_rate)
        / SQRT(
            pooled_rate * (1 - pooled_rate)
            * (
                1.0 / on_time_customers
                + 1.0 / late_customers
            )
        ) AS z_score
    FROM conversion_rates
),
p_value_calculation AS (
    SELECT
        *,
        ABS(z_score) AS abs_z,
        1.0 / (
            1.0 + 0.2316419 * ABS(z_score)
        ) AS t
    FROM z_test
),
normal_approximation AS (
    SELECT
        *,
        EXP(-POW(abs_z, 2) / 2)
            / SQRT(2 * PI()) AS normal_density
    FROM p_value_calculation
),
statistical_results AS (
    SELECT
        *,
        2 * normal_density * (
            0.319381530 * t
            - 0.356563782 * POW(t, 2)
            + 1.781477937 * POW(t, 3)
            - 1.821255978 * POW(t, 4)
            + 1.330274429 * POW(t, 5)
        ) AS p_value
    FROM normal_approximation
)

SELECT
    ROUND(100 * on_time_rate, 4)
        AS on_time_repeat_rate_pct,
    ROUND(100 * late_rate, 4)
        AS late_repeat_rate_pct,
    ROUND(
        100 * (on_time_rate - late_rate),
        4
    ) AS difference_percentage_points,
    ROUND(z_score, 4) AS z_score,
    ROUND(p_value, 4) AS p_value,
    CASE
        WHEN p_value < 0.05
            THEN 'Statistically Significant'
        ELSE 'Not Statistically Significant'
    END AS significance_result
FROM statistical_results;


-- =====================================================
-- CUSTOMER KPI 30: REPEAT RATE DIFFERENCE 95% CI
-- Estimate uncertainty around the difference in
-- 90-day repeat rates by first delivery experience
-- =====================================================

WITH delivery_counts AS (
    SELECT
        67826 AS on_time_customers,
        787 AS on_time_repeat_customers,
        5217 AS late_customers,
        41 AS late_repeat_customers
),
repeat_rates AS (
    SELECT
        on_time_repeat_customers * 1.0
            / on_time_customers AS on_time_rate,
        late_repeat_customers * 1.0
            / late_customers AS late_rate,
        on_time_customers,
        late_customers
    FROM delivery_counts
),
difference_estimate AS (
    SELECT
        on_time_rate,
        late_rate,
        on_time_rate - late_rate
            AS rate_difference,
        SQRT(
            on_time_rate * (1 - on_time_rate)
                / on_time_customers
            +
            late_rate * (1 - late_rate)
                / late_customers
        ) AS standard_error
    FROM repeat_rates
)

SELECT
    ROUND(100 * rate_difference, 4)
        AS difference_percentage_points,
    ROUND(100 * standard_error, 4)
        AS standard_error_pp,
    ROUND(
        100 * (rate_difference - 1.96 * standard_error),
        4
    ) AS ci_lower_95_pp,
    ROUND(
        100 * (rate_difference + 1.96 * standard_error),
        4
    ) AS ci_upper_95_pp,
    CASE
        WHEN rate_difference - 1.96 * standard_error > 0
            THEN 'CI Excludes Zero'
        WHEN rate_difference + 1.96 * standard_error < 0
            THEN 'CI Excludes Zero'
        ELSE 'CI Includes Zero'
    END AS confidence_interval_result
FROM difference_estimate;


-- =====================================================
-- CUSTOMER KPI 31: DELIVERY EXPERIENCE BY PURCHASE YEAR
-- Evaluate the consistency of 90-day repeat rates
-- across first-purchase cohorts
-- =====================================================

WITH analysis_date AS (
    SELECT
        MAX(order_purchase_timestamp) AS last_observed_purchase
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS purchase_number
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
first_orders AS (
    SELECT
        customer_unique_id,
        YEAR(order_purchase_timestamp) AS purchase_year,
        order_delivered_customer_date,
        CASE
            WHEN DATE(order_delivered_customer_date)
                 > DATE(order_estimated_delivery_date)
                THEN 'Late Delivery'
            ELSE 'On-Time Delivery'
        END AS delivery_performance
    FROM delivered_orders
    WHERE purchase_number = 1
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date
          >= order_purchase_timestamp
),
eligible_first_orders AS (
    SELECT
        f.customer_unique_id,
        f.purchase_year,
        f.order_delivered_customer_date,
        f.delivery_performance
    FROM first_orders AS f
    CROSS JOIN analysis_date AS a
    WHERE f.order_delivered_customer_date <=
          DATE_SUB(
              a.last_observed_purchase,
              INTERVAL 90 DAY
          )
),
customer_repeat_outcomes AS (
    SELECT
        f.customer_unique_id,
        f.purchase_year,
        f.delivery_performance,
        MAX(
            CASE
                WHEN d.purchase_number > 1
                 AND d.order_purchase_timestamp >
                     f.order_delivered_customer_date
                 AND d.order_purchase_timestamp <=
                     DATE_ADD(
                         f.order_delivered_customer_date,
                         INTERVAL 90 DAY
                     )
                THEN 1 ELSE 0
            END
        ) AS repeated_within_90_days
    FROM eligible_first_orders AS f
    INNER JOIN delivered_orders AS d
        ON f.customer_unique_id = d.customer_unique_id
    GROUP BY
        f.customer_unique_id,
        f.purchase_year,
        f.delivery_performance
)

SELECT
    purchase_year,
    delivery_performance,
    COUNT(*) AS eligible_customers,
    SUM(repeated_within_90_days)
        AS repeat_customers_90d,
    ROUND(
        100.0 * SUM(repeated_within_90_days)
        / COUNT(*),
        4
    ) AS repeat_rate_90d_pct
FROM customer_repeat_outcomes
GROUP BY purchase_year, delivery_performance
ORDER BY purchase_year, delivery_performance;


-- =====================================================
-- CUSTOMER KPI 32: YEAR-ADJUSTED DELIVERY ASSOCIATION
-- Calculate the Mantel-Haenszel common odds ratio
-- for 90-day repeat purchasing, stratified by year
-- =====================================================

WITH yearly_counts AS (
    SELECT
        2017 AS purchase_year,
        469 AS on_time_repeat,
        39743 - 469 AS on_time_non_repeat,
        21 AS late_repeat,
        2386 - 21 AS late_non_repeat

    UNION ALL

    SELECT
        2018,
        317,
        27822 - 317,
        20,
        2828 - 20
),
stratified_tables AS (
    SELECT
        purchase_year,
        on_time_repeat,
        on_time_non_repeat,
        late_repeat,
        late_non_repeat,
        (
            on_time_repeat
            + on_time_non_repeat
            + late_repeat
            + late_non_repeat
        ) AS stratum_total
    FROM yearly_counts
),
mantel_haenszel AS (
    SELECT
        SUM(
            on_time_repeat * late_non_repeat
            / stratum_total
        ) AS numerator,
        SUM(
            on_time_non_repeat * late_repeat
            / stratum_total
        ) AS denominator
    FROM stratified_tables
)

SELECT
    ROUND(
        numerator / denominator,
        4
    ) AS mh_adjusted_odds_ratio,
    CASE
        WHEN numerator / denominator > 1
            THEN 'Higher Repeat Odds: On-Time Delivery'
        WHEN numerator / denominator < 1
            THEN 'Higher Repeat Odds: Late Delivery'
        ELSE 'Equal Repeat Odds'
    END AS association_direction
FROM mantel_haenszel;


-- =====================================================
-- CUSTOMER KPI 33: COCHRAN-MANTEL-HAENSZEL TEST
-- Test the association between first delivery
-- performance and 90-day repeat purchasing,
-- controlling for first-purchase year (2017-2018)
-- =====================================================

WITH yearly_counts AS (
    SELECT
        2017 AS purchase_year,
        469 AS on_time_repeat,
        39743 - 469 AS on_time_non_repeat,
        21 AS late_repeat,
        2386 - 21 AS late_non_repeat

    UNION ALL

    SELECT
        2018,
        317,
        27822 - 317,
        20,
        2828 - 20
),
stratum_statistics AS (
    SELECT
        purchase_year,
        on_time_repeat AS observed_a,
        (
            on_time_repeat + on_time_non_repeat
        ) AS row_1_total,
        (
            late_repeat + late_non_repeat
        ) AS row_2_total,
        (
            on_time_repeat + late_repeat
        ) AS column_1_total,
        (
            on_time_non_repeat + late_non_repeat
        ) AS column_2_total,
        (
            on_time_repeat + on_time_non_repeat
            + late_repeat + late_non_repeat
        ) AS stratum_total
    FROM yearly_counts
),
expected_statistics AS (
    SELECT
        *,
        row_1_total * column_1_total
            / stratum_total AS expected_a,
        (
            row_1_total * row_2_total
            * column_1_total * column_2_total
        ) / (
            POW(stratum_total, 2)
            * (stratum_total - 1)
        ) AS variance_a
    FROM stratum_statistics
),
cmh_result AS (
    SELECT
        POW(
            SUM(observed_a - expected_a),
            2
        ) / SUM(variance_a) AS cmh_chi_square
    FROM expected_statistics
),
normal_approximation AS (
    SELECT
        cmh_chi_square,
        SQRT(cmh_chi_square) AS abs_z
    FROM cmh_result
),
p_value_terms AS (
    SELECT
        *,
        1.0 / (
            1.0 + 0.2316419 * abs_z
        ) AS t,
        EXP(-POW(abs_z, 2) / 2)
            / SQRT(2 * PI()) AS normal_density
    FROM normal_approximation
),
final_statistics AS (
    SELECT
        cmh_chi_square,
        2 * normal_density * (
            0.319381530 * t
            - 0.356563782 * POW(t, 2)
            + 1.781477937 * POW(t, 3)
            - 1.821255978 * POW(t, 4)
            + 1.330274429 * POW(t, 5)
        ) AS p_value
    FROM p_value_terms
)

SELECT
    ROUND(cmh_chi_square, 4)
        AS cmh_chi_square,
    1 AS degrees_of_freedom,
    ROUND(p_value, 4) AS p_value,
    CASE
        WHEN p_value < 0.05
            THEN 'Statistically Significant'
        ELSE 'Not Statistically Significant'
    END AS significance_result
FROM final_statistics;


-- =====================================================
-- CUSTOMER KPI 34: MANTEL-HAENSZEL ODDS RATIO 95% CI
-- Estimate the precision of the year-adjusted
-- association between first delivery performance
-- and 90-day repeat purchasing
-- =====================================================

WITH yearly_counts AS (
    SELECT
        2017 AS purchase_year,
        469.0 AS a,
        39743.0 - 469 AS b,
        21.0 AS c,
        2386.0 - 21 AS d

    UNION ALL

    SELECT
        2018,
        317.0,
        27822.0 - 317,
        20.0,
        2828.0 - 20
),
stratum_components AS (
    SELECT
        purchase_year,
        a,
        b,
        c,
        d,
        a + b + c + d AS n,
        a * d / (a + b + c + d) AS r,
        b * c / (a + b + c + d) AS s
    FROM yearly_counts
),
variance_components AS (
    SELECT
        *,
        (a + d) * a * d / POW(n, 2) AS p_component,
        (
            (a + d) * b * c
            + (b + c) * a * d
        ) / POW(n, 2) AS q_component,
        (b + c) * b * c / POW(n, 2) AS r_component
    FROM stratum_components
),
pooled_components AS (
    SELECT
        SUM(r) AS sum_r,
        SUM(s) AS sum_s,
        SUM(p_component) AS sum_p,
        SUM(q_component) AS sum_q,
        SUM(r_component) AS sum_r_component
    FROM variance_components
),
adjusted_estimates AS (
    SELECT
        sum_r / sum_s AS adjusted_odds_ratio,
        SQRT(
            sum_p / (2 * POW(sum_r, 2))
            + sum_q / (2 * sum_r * sum_s)
            + sum_r_component / (2 * POW(sum_s, 2))
        ) AS standard_error_log_or
    FROM pooled_components
)

SELECT
    ROUND(adjusted_odds_ratio, 4)
        AS mh_adjusted_odds_ratio,
    ROUND(standard_error_log_or, 4)
        AS standard_error_log_or,
    ROUND(
        EXP(
            LN(adjusted_odds_ratio)
            - 1.96 * standard_error_log_or
        ),
        4
    ) AS ci_lower_95,
    ROUND(
        EXP(
            LN(adjusted_odds_ratio)
            + 1.96 * standard_error_log_or
        ),
        4
    ) AS ci_upper_95,
    CASE
        WHEN EXP(
            LN(adjusted_odds_ratio)
            - 1.96 * standard_error_log_or
        ) > 1
            THEN 'CI Excludes One'
        WHEN EXP(
            LN(adjusted_odds_ratio)
            + 1.96 * standard_error_log_or
        ) < 1
            THEN 'CI Excludes One'
        ELSE 'CI Includes One'
    END AS confidence_interval_result
FROM adjusted_estimates;


-- =====================================================
-- CUSTOMER KPI 35: DELIVERY DELAY SEVERITY
-- Examine 90-day repeat purchase rates by the
-- severity of the first-order delivery delay
-- =====================================================

WITH analysis_date AS (
    SELECT
        MAX(order_purchase_timestamp) AS last_observed_purchase
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS purchase_number
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
first_orders AS (
    SELECT
        customer_unique_id,
        order_delivered_customer_date,
        DATEDIFF(
            DATE(order_delivered_customer_date),
            DATE(order_estimated_delivery_date)
        ) AS delay_days
    FROM delivered_orders
    WHERE purchase_number = 1
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date
          >= order_purchase_timestamp
),
eligible_first_orders AS (
    SELECT
        f.customer_unique_id,
        f.order_delivered_customer_date,
        CASE
            WHEN f.delay_days <= 0
                THEN 'On-Time'
            WHEN f.delay_days BETWEEN 1 AND 3
                THEN '1-3 Days Late'
            WHEN f.delay_days BETWEEN 4 AND 7
                THEN '4-7 Days Late'
            ELSE '8+ Days Late'
        END AS delay_category
    FROM first_orders AS f
    CROSS JOIN analysis_date AS a
    WHERE f.order_delivered_customer_date <=
          DATE_SUB(
              a.last_observed_purchase,
              INTERVAL 90 DAY
          )
),
customer_repeat_outcomes AS (
    SELECT
        f.customer_unique_id,
        f.delay_category,
        MAX(
            CASE
                WHEN d.purchase_number > 1
                 AND d.order_purchase_timestamp >
                     f.order_delivered_customer_date
                 AND d.order_purchase_timestamp <=
                     DATE_ADD(
                         f.order_delivered_customer_date,
                         INTERVAL 90 DAY
                     )
                THEN 1 ELSE 0
            END
        ) AS repeated_within_90_days
    FROM eligible_first_orders AS f
    INNER JOIN delivered_orders AS d
        ON f.customer_unique_id = d.customer_unique_id
    GROUP BY
        f.customer_unique_id,
        f.delay_category
)

SELECT
    delay_category,
    COUNT(*) AS eligible_customers,
    SUM(repeated_within_90_days)
        AS repeat_customers_90d,
    ROUND(
        100.0 * SUM(repeated_within_90_days)
        / COUNT(*),
        4
    ) AS repeat_rate_90d_pct
FROM customer_repeat_outcomes
GROUP BY delay_category
ORDER BY
    CASE delay_category
        WHEN 'On-Time' THEN 1
        WHEN '1-3 Days Late' THEN 2
        WHEN '4-7 Days Late' THEN 3
        WHEN '8+ Days Late' THEN 4
    END;


-- =====================================================
-- CUSTOMER KPI 36: DELIVERY DELAY CHI-SQUARE TEST
-- Test the association between delivery delay
-- severity and 90-day repeat purchase behavior
-- =====================================================

WITH delay_counts AS (
    SELECT
        'On-Time' AS delay_category,
        67826 AS eligible_customers,
        787 AS repeat_customers

    UNION ALL

    SELECT '1-3 Days Late', 1401, 12

    UNION ALL

    SELECT '4-7 Days Late', 1402, 9

    UNION ALL

    SELECT '8+ Days Late', 2414, 20
),
observed_counts AS (
    SELECT
        delay_category,
        eligible_customers,
        repeat_customers,
        eligible_customers - repeat_customers
            AS non_repeat_customers
    FROM delay_counts
),
overall_totals AS (
    SELECT
        SUM(eligible_customers) AS total_customers,
        SUM(repeat_customers) AS total_repeat,
        SUM(non_repeat_customers) AS total_non_repeat
    FROM observed_counts
),
expected_counts AS (
    SELECT
        o.delay_category,
        o.repeat_customers,
        o.non_repeat_customers,
        o.eligible_customers * t.total_repeat
            / t.total_customers AS expected_repeat,
        o.eligible_customers * t.total_non_repeat
            / t.total_customers AS expected_non_repeat
    FROM observed_counts AS o
    CROSS JOIN overall_totals AS t
),
chi_square_result AS (
    SELECT
        SUM(
            POW(
                repeat_customers - expected_repeat,
                2
            ) / expected_repeat
            +
            POW(
                non_repeat_customers - expected_non_repeat,
                2
            ) / expected_non_repeat
        ) AS chi_square_statistic
    FROM expected_counts
),
normal_transformation AS (
    SELECT
        chi_square_statistic,
        3 AS degrees_of_freedom,
        (
            POW(chi_square_statistic / 3.0, 1.0 / 3.0)
            - (1.0 - 2.0 / 27.0)
        ) / SQRT(2.0 / 27.0) AS z_score
    FROM chi_square_result
),
normal_approximation AS (
    SELECT
        *,
        ABS(z_score) AS abs_z,
        1.0 / (
            1.0 + 0.2316419 * ABS(z_score)
        ) AS t
    FROM normal_transformation
),
p_value_terms AS (
    SELECT
        *,
        EXP(-POW(abs_z, 2) / 2)
            / SQRT(2 * PI()) AS normal_density
    FROM normal_approximation
),
normal_tail AS (
    SELECT
        *,
        normal_density * (
            0.319381530 * t
            - 0.356563782 * POW(t, 2)
            + 1.781477937 * POW(t, 3)
            - 1.821255978 * POW(t, 4)
            + 1.330274429 * POW(t, 5)
        ) AS upper_tail_abs_z
    FROM p_value_terms
),
final_statistics AS (
    SELECT
        chi_square_statistic,
        degrees_of_freedom,
        CASE
            WHEN z_score >= 0
                THEN upper_tail_abs_z
            ELSE 1 - upper_tail_abs_z
        END AS p_value
    FROM normal_tail
)

SELECT
    ROUND(chi_square_statistic, 4)
        AS chi_square_statistic,
    degrees_of_freedom,
    ROUND(p_value, 4) AS approximate_p_value,
    CASE
        WHEN p_value < 0.05
            THEN 'Statistically Significant'
        ELSE 'Not Statistically Significant'
    END AS significance_result
FROM final_statistics;


-- =====================================================
-- CUSTOMER KPI 37: DELAY SEVERITY AMONG LATE DELIVERIES
-- Test whether repeat purchase behavior differs
-- across delay severity groups, excluding on-time
-- first deliveries
-- =====================================================

WITH late_delivery_counts AS (
    SELECT
        '1-3 Days Late' AS delay_category,
        1401 AS eligible_customers,
        12 AS repeat_customers

    UNION ALL

    SELECT
        '4-7 Days Late',
        1402,
        9

    UNION ALL

    SELECT
        '8+ Days Late',
        2414,
        20
),
observed_counts AS (
    SELECT
        delay_category,
        eligible_customers,
        repeat_customers,
        eligible_customers - repeat_customers
            AS non_repeat_customers
    FROM late_delivery_counts
),
overall_totals AS (
    SELECT
        SUM(eligible_customers) AS total_customers,
        SUM(repeat_customers) AS total_repeat,
        SUM(non_repeat_customers) AS total_non_repeat
    FROM observed_counts
),
expected_counts AS (
    SELECT
        o.delay_category,
        o.repeat_customers,
        o.non_repeat_customers,
        o.eligible_customers * t.total_repeat
            / t.total_customers AS expected_repeat,
        o.eligible_customers * t.total_non_repeat
            / t.total_customers AS expected_non_repeat
    FROM observed_counts AS o
    CROSS JOIN overall_totals AS t
),
chi_square_result AS (
    SELECT
        SUM(
            POW(
                repeat_customers - expected_repeat,
                2
            ) / expected_repeat
            +
            POW(
                non_repeat_customers - expected_non_repeat,
                2
            ) / expected_non_repeat
        ) AS chi_square_statistic
    FROM expected_counts
),
statistical_results AS (
    SELECT
        chi_square_statistic,
        EXP(-chi_square_statistic / 2)
            AS p_value
    FROM chi_square_result
)

SELECT
    ROUND(chi_square_statistic, 4)
        AS chi_square_statistic,
    2 AS degrees_of_freedom,
    ROUND(p_value, 4) AS p_value,
    CASE
        WHEN p_value < 0.05
            THEN 'Statistically Significant'
        ELSE 'Not Statistically Significant'
    END AS significance_result
FROM statistical_results;


-- =====================================================
-- CUSTOMER KPI 38: DELIVERY EXPERIENCE BY ORDER VALUE
-- Compare 90-day repeat purchase rates across
-- first-order value quintiles and delivery outcomes
-- =====================================================

WITH analysis_date AS (
    SELECT
        MAX(order_purchase_timestamp) AS last_observed_purchase
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_order_revenue AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        SUM(oi.price) AS first_order_product_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
),
ranked_orders AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp, order_id
        ) AS purchase_number
    FROM delivered_order_revenue
),
first_orders AS (
    SELECT
        customer_unique_id,
        order_delivered_customer_date,
        first_order_product_revenue,
        CASE
            WHEN DATE(order_delivered_customer_date)
                 > DATE(order_estimated_delivery_date)
                THEN 'Late Delivery'
            ELSE 'On-Time Delivery'
        END AS delivery_performance
    FROM ranked_orders
    WHERE purchase_number = 1
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date
          >= order_purchase_timestamp
),
eligible_first_orders AS (
    SELECT
        f.*
    FROM first_orders AS f
    CROSS JOIN analysis_date AS a
    WHERE f.order_delivered_customer_date <=
          DATE_SUB(
              a.last_observed_purchase,
              INTERVAL 90 DAY
          )
),
customer_repeat_outcomes AS (
    SELECT
        f.customer_unique_id,
        f.first_order_product_revenue,
        f.delivery_performance,
        MAX(
            CASE
                WHEN d.purchase_number > 1
                 AND d.order_purchase_timestamp >
                     f.order_delivered_customer_date
                 AND d.order_purchase_timestamp <=
                     DATE_ADD(
                         f.order_delivered_customer_date,
                         INTERVAL 90 DAY
                     )
                THEN 1 ELSE 0
            END
        ) AS repeated_within_90_days
    FROM eligible_first_orders AS f
    INNER JOIN ranked_orders AS d
        ON f.customer_unique_id = d.customer_unique_id
    GROUP BY
        f.customer_unique_id,
        f.first_order_product_revenue,
        f.delivery_performance
),
value_percentiles AS (
    SELECT
        *,
        CUME_DIST() OVER (
            ORDER BY first_order_product_revenue
        ) AS value_percentile
    FROM customer_repeat_outcomes
),
value_segments AS (
    SELECT
        LEAST(
            CEIL(value_percentile * 5),
            5
        ) AS first_order_value_quintile,
        delivery_performance,
        repeated_within_90_days
    FROM value_percentiles
)

SELECT
    first_order_value_quintile,
    delivery_performance,
    COUNT(*) AS eligible_customers,
    SUM(repeated_within_90_days)
        AS repeat_customers_90d,
    ROUND(
        100.0 * SUM(repeated_within_90_days)
        / COUNT(*),
        4
    ) AS repeat_rate_90d_pct
FROM value_segments
GROUP BY
    first_order_value_quintile,
    delivery_performance
ORDER BY
    first_order_value_quintile,
    delivery_performance;


-- =====================================================
-- CUSTOMER KPI 39: VALUE-ADJUSTED DELIVERY ASSOCIATION
-- Calculate the Mantel-Haenszel common odds ratio
-- for delivery experience and 90-day repeat purchase,
-- stratified by first-order value quintile
-- =====================================================

WITH quintile_counts AS (
    SELECT
        1 AS value_quintile,
        167 AS on_time_repeat,
        13548 - 167 AS on_time_non_repeat,
        4 AS late_repeat,
        907 - 4 AS late_non_repeat

    UNION ALL

    SELECT
        2,
        153,
        13715 - 153,
        7,
        1005 - 7

    UNION ALL

    SELECT
        3,
        159,
        13519 - 159,
        6,
        1000 - 6

    UNION ALL

    SELECT
        4,
        152,
        13593 - 152,
        12,
        1147 - 12

    UNION ALL

    SELECT
        5,
        156,
        13451 - 156,
        12,
        1158 - 12
),
stratified_tables AS (
    SELECT
        value_quintile,
        on_time_repeat,
        on_time_non_repeat,
        late_repeat,
        late_non_repeat,
        (
            on_time_repeat
            + on_time_non_repeat
            + late_repeat
            + late_non_repeat
        ) AS stratum_total
    FROM quintile_counts
),
mantel_haenszel AS (
    SELECT
        SUM(
            on_time_repeat * late_non_repeat
            / stratum_total
        ) AS numerator,
        SUM(
            on_time_non_repeat * late_repeat
            / stratum_total
        ) AS denominator
    FROM stratified_tables
)

SELECT
    ROUND(
        numerator / denominator,
        4
    ) AS mh_value_adjusted_odds_ratio,
    CASE
        WHEN numerator / denominator > 1
            THEN 'Higher Repeat Odds: On-Time Delivery'
        WHEN numerator / denominator < 1
            THEN 'Higher Repeat Odds: Late Delivery'
        ELSE 'Equal Repeat Odds'
    END AS association_direction
FROM mantel_haenszel;


-- =====================================================
-- CUSTOMER KPI 40: VALUE-ADJUSTED CMH TEST
-- Test the association between first delivery
-- performance and 90-day repeat purchasing,
-- controlling for first-order value quintile
-- =====================================================

WITH quintile_counts AS (
    SELECT
        1 AS value_quintile,
        167.0 AS a,
        13548.0 - 167 AS b,
        4.0 AS c,
        907.0 - 4 AS d

    UNION ALL
    SELECT 2, 153.0, 13715.0 - 153,
           7.0, 1005.0 - 7

    UNION ALL
    SELECT 3, 159.0, 13519.0 - 159,
           6.0, 1000.0 - 6

    UNION ALL
    SELECT 4, 152.0, 13593.0 - 152,
           12.0, 1147.0 - 12

    UNION ALL
    SELECT 5, 156.0, 13451.0 - 156,
           12.0, 1158.0 - 12
),
stratum_statistics AS (
    SELECT
        value_quintile,
        a,
        b,
        c,
        d,
        a + b + c + d AS n,
        (a + b) * (a + c)
            / (a + b + c + d) AS expected_a,
        (a + b) * (c + d) * (a + c) * (b + d)
            / (
                POW(a + b + c + d, 2)
                * (a + b + c + d - 1)
            ) AS variance_a
    FROM quintile_counts
),
cmh_components AS (
    SELECT
        SUM(a - expected_a) AS observed_minus_expected,
        SUM(variance_a) AS total_variance
    FROM stratum_statistics
),
cmh_statistic AS (
    SELECT
        POW(observed_minus_expected, 2)
            / total_variance AS chi_square_statistic
    FROM cmh_components
),
normal_approximation AS (
    SELECT
        chi_square_statistic,
        SQRT(chi_square_statistic) AS z_score
    FROM cmh_statistic
),
tail_calculation AS (
    SELECT
        chi_square_statistic,
        z_score,
        1.0 / (1.0 + 0.2316419 * z_score) AS t
    FROM normal_approximation
),
p_value_calculation AS (
    SELECT
        chi_square_statistic,
        2 * (
            EXP(-POW(z_score, 2) / 2)
            / SQRT(2 * PI())
        ) * (
            0.319381530 * t
            - 0.356563782 * POW(t, 2)
            + 1.781477937 * POW(t, 3)
            - 1.821255978 * POW(t, 4)
            + 1.330274429 * POW(t, 5)
        ) AS p_value
    FROM tail_calculation
)

SELECT
    ROUND(chi_square_statistic, 4)
        AS cmh_chi_square,
    1 AS degrees_of_freedom,
    ROUND(p_value, 4) AS p_value,
    CASE
        WHEN p_value < 0.05
            THEN 'Statistically Significant'
        ELSE 'Not Statistically Significant'
    END AS significance_result
FROM p_value_calculation;


-- =====================================================
-- CUSTOMER KPI 41: VALUE-ADJUSTED MH ODDS RATIO CI
-- Estimate the 95% confidence interval using the
-- Robins-Breslow-Greenland variance estimator
-- =====================================================

WITH quintile_counts AS (
    SELECT
        1 AS value_quintile,
        167.0 AS a,
        13548.0 - 167 AS b,
        4.0 AS c,
        907.0 - 4 AS d

    UNION ALL
    SELECT 2, 153.0, 13715.0 - 153,
           7.0, 1005.0 - 7

    UNION ALL
    SELECT 3, 159.0, 13519.0 - 159,
           6.0, 1000.0 - 6

    UNION ALL
    SELECT 4, 152.0, 13593.0 - 152,
           12.0, 1147.0 - 12

    UNION ALL
    SELECT 5, 156.0, 13451.0 - 156,
           12.0, 1158.0 - 12
),
stratum_components AS (
    SELECT
        value_quintile,
        a,
        b,
        c,
        d,
        a + b + c + d AS n,
        a * d / (a + b + c + d) AS r,
        b * c / (a + b + c + d) AS s
    FROM quintile_counts
),
variance_components AS (
    SELECT
        *,
        (a + d) * a * d / POW(n, 2)
            AS p_component,
        (
            (a + d) * b * c
            + (b + c) * a * d
        ) / POW(n, 2) AS q_component,
        (b + c) * b * c / POW(n, 2)
            AS r_component
    FROM stratum_components
),
pooled_components AS (
    SELECT
        SUM(r) AS sum_r,
        SUM(s) AS sum_s,
        SUM(p_component) AS sum_p,
        SUM(q_component) AS sum_q,
        SUM(r_component) AS sum_r_component
    FROM variance_components
),
adjusted_estimates AS (
    SELECT
        sum_r / sum_s AS adjusted_odds_ratio,
        SQRT(
            sum_p / (2 * POW(sum_r, 2))
            + sum_q / (2 * sum_r * sum_s)
            + sum_r_component / (2 * POW(sum_s, 2))
        ) AS standard_error_log_or
    FROM pooled_components
)

SELECT
    ROUND(adjusted_odds_ratio, 4)
        AS mh_value_adjusted_odds_ratio,
    ROUND(standard_error_log_or, 4)
        AS standard_error_log_or,
    ROUND(
        EXP(
            LN(adjusted_odds_ratio)
            - 1.96 * standard_error_log_or
        ),
        4
    ) AS ci_lower_95,
    ROUND(
        EXP(
            LN(adjusted_odds_ratio)
            + 1.96 * standard_error_log_or
        ),
        4
    ) AS ci_upper_95,
    CASE
        WHEN EXP(
            LN(adjusted_odds_ratio)
            - 1.96 * standard_error_log_or
        ) > 1
            THEN 'CI Excludes One'
        WHEN EXP(
            LN(adjusted_odds_ratio)
            + 1.96 * standard_error_log_or
        ) < 1
            THEN 'CI Excludes One'
        ELSE 'CI Includes One'
    END AS confidence_interval_result
FROM adjusted_estimates;


-- =====================================================
-- CUSTOMER KPI 42: JOINTLY ADJUSTED DELIVERY ASSOCIATION
-- Estimate the Mantel-Haenszel odds ratio for
-- 90-day repeat purchasing, stratified jointly by
-- first-order purchase year and order value quintile
-- =====================================================

WITH analysis_date AS (
    SELECT
        MAX(order_purchase_timestamp)
            AS last_observed_purchase
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_order_revenue AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        SUM(oi.price) AS order_product_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
),
ranked_orders AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp, order_id
        ) AS purchase_number
    FROM delivered_order_revenue
),
first_orders AS (
    SELECT
        customer_unique_id,
        YEAR(order_purchase_timestamp)
            AS purchase_year,
        order_delivered_customer_date,
        order_product_revenue,
        CASE
            WHEN DATE(order_delivered_customer_date)
                 > DATE(order_estimated_delivery_date)
                THEN 'Late'
            ELSE 'On-Time'
        END AS delivery_performance
    FROM ranked_orders
    WHERE purchase_number = 1
      AND YEAR(order_purchase_timestamp) IN (2017, 2018)
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date
          >= order_purchase_timestamp
),
eligible_first_orders AS (
    SELECT
        f.*
    FROM first_orders AS f
    CROSS JOIN analysis_date AS a
    WHERE f.order_delivered_customer_date <=
          DATE_SUB(
              a.last_observed_purchase,
              INTERVAL 90 DAY
          )
),
customer_repeat_outcomes AS (
    SELECT
        f.customer_unique_id,
        f.purchase_year,
        f.order_product_revenue,
        f.delivery_performance,
        MAX(
            CASE
                WHEN d.purchase_number > 1
                 AND d.order_purchase_timestamp >
                     f.order_delivered_customer_date
                 AND d.order_purchase_timestamp <=
                     DATE_ADD(
                         f.order_delivered_customer_date,
                         INTERVAL 90 DAY
                     )
                THEN 1 ELSE 0
            END
        ) AS repeated_within_90_days
    FROM eligible_first_orders AS f
    INNER JOIN ranked_orders AS d
        ON f.customer_unique_id = d.customer_unique_id
    GROUP BY
        f.customer_unique_id,
        f.purchase_year,
        f.order_product_revenue,
        f.delivery_performance
),
value_percentiles AS (
    SELECT
        *,
        CUME_DIST() OVER (
            PARTITION BY purchase_year
            ORDER BY order_product_revenue
        ) AS value_percentile
    FROM customer_repeat_outcomes
),
stratified_customers AS (
    SELECT
        purchase_year,
        LEAST(
            CEIL(value_percentile * 5),
            5
        ) AS value_quintile,
        delivery_performance,
        repeated_within_90_days
    FROM value_percentiles
),
stratum_counts AS (
    SELECT
        purchase_year,
        value_quintile,
        SUM(
            CASE
                WHEN delivery_performance = 'On-Time'
                 AND repeated_within_90_days = 1
                THEN 1 ELSE 0
            END
        ) AS a,
        SUM(
            CASE
                WHEN delivery_performance = 'On-Time'
                 AND repeated_within_90_days = 0
                THEN 1 ELSE 0
            END
        ) AS b,
        SUM(
            CASE
                WHEN delivery_performance = 'Late'
                 AND repeated_within_90_days = 1
                THEN 1 ELSE 0
            END
        ) AS c,
        SUM(
            CASE
                WHEN delivery_performance = 'Late'
                 AND repeated_within_90_days = 0
                THEN 1 ELSE 0
            END
        ) AS d
    FROM stratified_customers
    GROUP BY
        purchase_year,
        value_quintile
),
mh_components AS (
    SELECT
        SUM(
            1.0 * a * d / (a + b + c + d)
        ) AS numerator,
        SUM(
            1.0 * b * c / (a + b + c + d)
        ) AS denominator,
        COUNT(*) AS total_strata
    FROM stratum_counts
)

SELECT
    total_strata,
    ROUND(
        numerator / NULLIF(denominator, 0),
        4
    ) AS jointly_adjusted_mh_odds_ratio,
    CASE
        WHEN numerator > denominator
            THEN 'Higher Repeat Odds: On-Time Delivery'
        WHEN numerator < denominator
            THEN 'Higher Repeat Odds: Late Delivery'
        ELSE 'Equal Repeat Odds'
    END AS association_direction
FROM mh_components;


-- =====================================================
-- CUSTOMER KPI 43: JOINTLY ADJUSTED CMH TEST
-- Test delivery experience vs 90-day repeat purchase
-- controlling jointly for first-purchase year
-- and first-order value quintile
-- =====================================================

WITH analysis_date AS (
    SELECT
        MAX(order_purchase_timestamp)
            AS last_observed_purchase
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_order_revenue AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        SUM(oi.price) AS order_product_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
),
ranked_orders AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp, order_id
        ) AS purchase_number
    FROM delivered_order_revenue
),
first_orders AS (
    SELECT
        customer_unique_id,
        YEAR(order_purchase_timestamp) AS purchase_year,
        order_delivered_customer_date,
        order_product_revenue,
        CASE
            WHEN DATE(order_delivered_customer_date)
                 > DATE(order_estimated_delivery_date)
                THEN 'Late'
            ELSE 'On-Time'
        END AS delivery_performance
    FROM ranked_orders
    WHERE purchase_number = 1
      AND YEAR(order_purchase_timestamp) IN (2017, 2018)
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date
          >= order_purchase_timestamp
),
eligible_first_orders AS (
    SELECT
        f.*
    FROM first_orders AS f
    CROSS JOIN analysis_date AS a
    WHERE f.order_delivered_customer_date <=
          DATE_SUB(
              a.last_observed_purchase,
              INTERVAL 90 DAY
          )
),
customer_repeat_outcomes AS (
    SELECT
        f.customer_unique_id,
        f.purchase_year,
        f.order_product_revenue,
        f.delivery_performance,
        MAX(
            CASE
                WHEN d.purchase_number > 1
                 AND d.order_purchase_timestamp >
                     f.order_delivered_customer_date
                 AND d.order_purchase_timestamp <=
                     DATE_ADD(
                         f.order_delivered_customer_date,
                         INTERVAL 90 DAY
                     )
                THEN 1 ELSE 0
            END
        ) AS repeated_within_90_days
    FROM eligible_first_orders AS f
    INNER JOIN ranked_orders AS d
        ON f.customer_unique_id = d.customer_unique_id
    GROUP BY
        f.customer_unique_id,
        f.purchase_year,
        f.order_product_revenue,
        f.delivery_performance
),
value_percentiles AS (
    SELECT
        *,
        CUME_DIST() OVER (
            PARTITION BY purchase_year
            ORDER BY order_product_revenue
        ) AS value_percentile
    FROM customer_repeat_outcomes
),
stratified_customers AS (
    SELECT
        purchase_year,
        LEAST(
            CEIL(value_percentile * 5),
            5
        ) AS value_quintile,
        delivery_performance,
        repeated_within_90_days
    FROM value_percentiles
),
stratum_counts AS (
    SELECT
        purchase_year,
        value_quintile,
        SUM(
            CASE
                WHEN delivery_performance = 'On-Time'
                 AND repeated_within_90_days = 1
                THEN 1 ELSE 0
            END
        ) AS a,
        SUM(
            CASE
                WHEN delivery_performance = 'On-Time'
                 AND repeated_within_90_days = 0
                THEN 1 ELSE 0
            END
        ) AS b,
        SUM(
            CASE
                WHEN delivery_performance = 'Late'
                 AND repeated_within_90_days = 1
                THEN 1 ELSE 0
            END
        ) AS c,
        SUM(
            CASE
                WHEN delivery_performance = 'Late'
                 AND repeated_within_90_days = 0
                THEN 1 ELSE 0
            END
        ) AS d
    FROM stratified_customers
    GROUP BY purchase_year, value_quintile
),
stratum_statistics AS (
    SELECT
        *,
        a + b + c + d AS n,
        (a + b) * (a + c)
            / (a + b + c + d) AS expected_a,
        1.0 * (a + b) * (c + d)
            * (a + c) * (b + d)
            / (
                POW(a + b + c + d, 2)
                * (a + b + c + d - 1)
            ) AS variance_a
    FROM stratum_counts
),
cmh_components AS (
    SELECT
        SUM(a - expected_a) AS observed_minus_expected,
        SUM(variance_a) AS total_variance
    FROM stratum_statistics
),
cmh_statistic AS (
    SELECT
        POW(observed_minus_expected, 2)
            / total_variance AS chi_square_statistic
    FROM cmh_components
),
normal_approximation AS (
    SELECT
        chi_square_statistic,
        SQRT(chi_square_statistic) AS z_score
    FROM cmh_statistic
),
tail_calculation AS (
    SELECT
        chi_square_statistic,
        z_score,
        1.0 / (1.0 + 0.2316419 * z_score) AS t
    FROM normal_approximation
),
p_value_calculation AS (
    SELECT
        chi_square_statistic,
        2 * (
            EXP(-POW(z_score, 2) / 2)
            / SQRT(2 * PI())
        ) * (
            0.319381530 * t
            - 0.356563782 * POW(t, 2)
            + 1.781477937 * POW(t, 3)
            - 1.821255978 * POW(t, 4)
            + 1.330274429 * POW(t, 5)
        ) AS p_value
    FROM tail_calculation
)

SELECT
    ROUND(chi_square_statistic, 4)
        AS cmh_chi_square,
    1 AS degrees_of_freedom,
    ROUND(p_value, 4) AS p_value,
    CASE
        WHEN p_value < 0.05
            THEN 'Statistically Significant'
        ELSE 'Not Statistically Significant'
    END AS significance_result
FROM p_value_calculation;


-- =====================================================
-- CUSTOMER KPI 44: JOINT ADJUSTMENT STRATUM VALIDATION
-- Inspect the 2x2 contingency tables across
-- purchase year and first-order value quintiles
-- before calculating the pooled confidence interval
-- =====================================================

WITH analysis_date AS (
    SELECT
        MAX(order_purchase_timestamp)
            AS last_observed_purchase
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_order_revenue AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        SUM(oi.price) AS order_product_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
),
ranked_orders AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp, order_id
        ) AS purchase_number
    FROM delivered_order_revenue
),
first_orders AS (
    SELECT
        customer_unique_id,
        YEAR(order_purchase_timestamp) AS purchase_year,
        order_delivered_customer_date,
        order_product_revenue,
        CASE
            WHEN DATE(order_delivered_customer_date)
                 > DATE(order_estimated_delivery_date)
                THEN 'Late'
            ELSE 'On-Time'
        END AS delivery_performance
    FROM ranked_orders
    WHERE purchase_number = 1
      AND YEAR(order_purchase_timestamp) IN (2017, 2018)
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date
          >= order_purchase_timestamp
),
eligible_first_orders AS (
    SELECT
        f.*
    FROM first_orders AS f
    CROSS JOIN analysis_date AS a
    WHERE f.order_delivered_customer_date <=
          DATE_SUB(
              a.last_observed_purchase,
              INTERVAL 90 DAY
          )
),
customer_repeat_outcomes AS (
    SELECT
        f.customer_unique_id,
        f.purchase_year,
        f.order_product_revenue,
        f.delivery_performance,
        MAX(
            CASE
                WHEN d.purchase_number > 1
                 AND d.order_purchase_timestamp >
                     f.order_delivered_customer_date
                 AND d.order_purchase_timestamp <=
                     DATE_ADD(
                         f.order_delivered_customer_date,
                         INTERVAL 90 DAY
                     )
                THEN 1 ELSE 0
            END
        ) AS repeated_within_90_days
    FROM eligible_first_orders AS f
    INNER JOIN ranked_orders AS d
        ON f.customer_unique_id = d.customer_unique_id
    GROUP BY
        f.customer_unique_id,
        f.purchase_year,
        f.order_product_revenue,
        f.delivery_performance
),
value_percentiles AS (
    SELECT
        *,
        CUME_DIST() OVER (
            PARTITION BY purchase_year
            ORDER BY order_product_revenue
        ) AS value_percentile
    FROM customer_repeat_outcomes
),
stratified_customers AS (
    SELECT
        purchase_year,
        LEAST(
            CEIL(value_percentile * 5),
            5
        ) AS value_quintile,
        delivery_performance,
        repeated_within_90_days
    FROM value_percentiles
)

SELECT
    purchase_year,
    value_quintile,
    SUM(
        CASE
            WHEN delivery_performance = 'On-Time'
             AND repeated_within_90_days = 1
            THEN 1 ELSE 0
        END
    ) AS a_on_time_repeat,
    SUM(
        CASE
            WHEN delivery_performance = 'On-Time'
             AND repeated_within_90_days = 0
            THEN 1 ELSE 0
        END
    ) AS b_on_time_no_repeat,
    SUM(
        CASE
            WHEN delivery_performance = 'Late'
             AND repeated_within_90_days = 1
            THEN 1 ELSE 0
        END
    ) AS c_late_repeat,
    SUM(
        CASE
            WHEN delivery_performance = 'Late'
             AND repeated_within_90_days = 0
            THEN 1 ELSE 0
        END
    ) AS d_late_no_repeat
FROM stratified_customers
GROUP BY
    purchase_year,
    value_quintile
ORDER BY
    purchase_year,
    value_quintile;


-- =====================================================
-- CUSTOMER KPI 45: JOINTLY ADJUSTED MH ODDS RATIO CI
-- Calculate the 95% confidence interval using the
-- Robins-Breslow-Greenland variance estimator
-- Stratified by purchase year and order value quintile
-- =====================================================

WITH stratum_counts AS (
    SELECT 2017 AS purchase_year, 1 AS value_quintile,
           100.0 AS a, 7919.0 AS b, 2.0 AS c, 403.0 AS d
    UNION ALL SELECT 2017, 2, 98.0, 7798.0, 2.0, 413.0
    UNION ALL SELECT 2017, 3, 91.0, 7960.0, 6.0, 482.0
    UNION ALL SELECT 2017, 4, 92.0, 7821.0, 5.0, 511.0
    UNION ALL SELECT 2017, 5, 88.0, 7776.0, 6.0, 556.0

    UNION ALL SELECT 2018, 1, 69.0, 5552.0, 2.0, 503.0
    UNION ALL SELECT 2018, 2, 53.0, 5447.0, 5.0, 580.0
    UNION ALL SELECT 2018, 3, 67.0, 5570.0, 0.0, 537.0
    UNION ALL SELECT 2018, 4, 59.0, 5478.0, 7.0, 588.0
    UNION ALL SELECT 2018, 5, 69.0, 5458.0, 6.0, 600.0
),
stratum_components AS (
    SELECT
        purchase_year,
        value_quintile,
        a, b, c, d,
        a + b + c + d AS n,
        a * d / (a + b + c + d) AS r,
        b * c / (a + b + c + d) AS s
    FROM stratum_counts
),
variance_components AS (
    SELECT
        *,
        (a + d) * a * d / POW(n, 2)
            AS p_component,
        (
            (a + d) * b * c
            + (b + c) * a * d
        ) / POW(n, 2) AS q_component,
        (b + c) * b * c / POW(n, 2)
            AS t_component
    FROM stratum_components
),
pooled_components AS (
    SELECT
        COUNT(*) AS total_strata,
        SUM(r) AS sum_r,
        SUM(s) AS sum_s,
        SUM(p_component) AS sum_p,
        SUM(q_component) AS sum_q,
        SUM(t_component) AS sum_t
    FROM variance_components
),
adjusted_estimates AS (
    SELECT
        total_strata,
        sum_r / NULLIF(sum_s, 0)
            AS adjusted_odds_ratio,
        SQRT(
            sum_p / (2 * POW(sum_r, 2))
            + sum_q / (2 * sum_r * sum_s)
            + sum_t / (2 * POW(sum_s, 2))
        ) AS standard_error_log_or
    FROM pooled_components
),
confidence_intervals AS (
    SELECT
        total_strata,
        adjusted_odds_ratio,
        standard_error_log_or,
        EXP(
            LN(adjusted_odds_ratio)
            - 1.96 * standard_error_log_or
        ) AS ci_lower,
        EXP(
            LN(adjusted_odds_ratio)
            + 1.96 * standard_error_log_or
        ) AS ci_upper
    FROM adjusted_estimates
)

SELECT
    total_strata,
    ROUND(adjusted_odds_ratio, 4)
        AS jointly_adjusted_mh_odds_ratio,
    ROUND(standard_error_log_or, 4)
        AS standard_error_log_or,
    ROUND(ci_lower, 4) AS ci_lower_95,
    ROUND(ci_upper, 4) AS ci_upper_95,
    CASE
        WHEN ci_lower > 1 OR ci_upper < 1
            THEN 'CI Excludes One'
        ELSE 'CI Includes One'
    END AS confidence_interval_result
FROM confidence_intervals;


-- =====================================================
-- POWER BI REVENUE DATASET VALIDATION
-- Build an order-level revenue dataset for Power BI
-- One row per delivered order with order items
-- =====================================================

WITH order_financials AS (
    SELECT
        oi.order_id,
        ROUND(SUM(oi.price), 2)
            AS product_revenue,
        ROUND(SUM(oi.freight_value), 2)
            AS freight_revenue,
        COUNT(*) AS item_count,
        COUNT(DISTINCT oi.product_id)
            AS distinct_products
    FROM order_items AS oi
    GROUP BY oi.order_id
),
power_bi_revenue AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        DATE(o.order_purchase_timestamp)
            AS purchase_date,
        YEAR(o.order_purchase_timestamp)
            AS purchase_year,
        DATE_FORMAT(
            o.order_purchase_timestamp,
            '%Y-%m'
        ) AS purchase_month,
        f.product_revenue,
        f.freight_revenue,
        f.product_revenue + f.freight_revenue
            AS total_order_value,
        f.item_count,
        f.distinct_products,
        CASE
            WHEN o.order_delivered_customer_date IS NULL
              OR o.order_estimated_delivery_date IS NULL
                THEN 'Unknown'
            WHEN DATE(o.order_delivered_customer_date)
                 > DATE(o.order_estimated_delivery_date)
                THEN 'Late'
            ELSE 'On-Time'
        END AS delivery_performance
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_financials AS f
        ON o.order_id = f.order_id
    WHERE o.order_status = 'delivered'
)

SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT order_id)
        AS distinct_orders,
    COUNT(DISTINCT customer_unique_id)
        AS unique_customers,
    ROUND(SUM(product_revenue), 2)
        AS total_product_revenue,
    ROUND(SUM(freight_revenue), 2)
        AS total_freight_revenue,
    ROUND(SUM(total_order_value), 2)
        AS total_order_value,
    ROUND(AVG(product_revenue), 2)
        AS average_order_value,
    SUM(item_count) AS total_items,
    SUM(
        CASE
            WHEN delivery_performance = 'Late'
                THEN 1 ELSE 0
        END
    ) AS late_orders,
    SUM(
        CASE
            WHEN delivery_performance = 'Unknown'
                THEN 1 ELSE 0
        END
    ) AS unknown_delivery_orders
FROM power_bi_revenue;


-- =====================================================
-- CREATE POWER BI ORDER FACT TABLE
-- One row per delivered order
-- Preserve product revenue and freight separately
-- Avoid duplicate revenue from order-level joins
-- =====================================================

CREATE OR REPLACE VIEW pbi_fact_orders AS
WITH order_financials AS (
    SELECT
        oi.order_id,
        ROUND(SUM(oi.price), 2)
            AS product_revenue,
        ROUND(SUM(oi.freight_value), 2)
            AS freight_revenue,
        COUNT(*) AS item_count,
        COUNT(DISTINCT oi.product_id)
            AS distinct_products
    FROM order_items AS oi
    GROUP BY oi.order_id
)
SELECT
    o.order_id,
    c.customer_unique_id,
    DATE(o.order_purchase_timestamp)
        AS purchase_date,
    YEAR(o.order_purchase_timestamp)
        AS purchase_year,
    MONTH(o.order_purchase_timestamp)
        AS purchase_month_number,
    DATE_FORMAT(
        o.order_purchase_timestamp,
        '%Y-%m'
    ) AS purchase_month,
    c.customer_state,
    f.product_revenue,
    f.freight_revenue,
    f.product_revenue + f.freight_revenue
        AS total_order_value,
    f.item_count,
    f.distinct_products,
    CASE
        WHEN o.order_delivered_customer_date IS NULL
          OR o.order_estimated_delivery_date IS NULL
            THEN 'Unknown'
        WHEN DATE(o.order_delivered_customer_date)
             > DATE(o.order_estimated_delivery_date)
            THEN 'Late'
        ELSE 'On-Time'
    END AS delivery_performance
FROM orders AS o
INNER JOIN customers AS c
    ON o.customer_id = c.customer_id
INNER JOIN order_financials AS f
    ON o.order_id = f.order_id
WHERE o.order_status = 'delivered';


-- =====================================================
-- POWER BI ORDER FACT VIEW VALIDATION
-- Validate order grain and financial KPI consistency
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    ROUND(SUM(product_revenue), 2) AS product_revenue,
    ROUND(SUM(freight_revenue), 2) AS freight_revenue,
    ROUND(SUM(total_order_value), 2) AS total_order_value,
    ROUND(AVG(product_revenue), 2) AS product_aov,
    SUM(item_count) AS total_items,
    SUM(delivery_performance = 'Late') AS late_orders,
    SUM(delivery_performance = 'Unknown') AS unknown_delivery
FROM olist_ecommerce.pbi_fact_orders;


-- =====================================================
-- DELIVERY CLASSIFICATION RECONCILIATION
-- Compare timestamp-level and date-level late deliveries
-- Identify same-day timestamp discrepancies
-- =====================================================

SELECT
    COUNT(*) AS delivered_orders,

    SUM(
        order_delivered_customer_date >
        order_estimated_delivery_date
    ) AS timestamp_late_orders,

    SUM(
        DATE(order_delivered_customer_date) >
        DATE(order_estimated_delivery_date)
    ) AS date_late_orders,

    SUM(
        DATE(order_delivered_customer_date) =
        DATE(order_estimated_delivery_date)
        AND order_delivered_customer_date >
            order_estimated_delivery_date
    ) AS same_day_timestamp_late,

    SUM(
        order_delivered_customer_date IS NULL
        OR order_estimated_delivery_date IS NULL
    ) AS unknown_delivery

FROM olist_ecommerce.orders
WHERE order_status = 'delivered';


-- =====================================================
-- CREATE POWER BI PRODUCT FACT TABLE
-- One row per delivered order item
-- Support product category and price segment analysis
-- Preserve item-level revenue without duplication
-- =====================================================

CREATE OR REPLACE VIEW pbi_fact_order_items AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    DATE(o.order_purchase_timestamp)
        AS purchase_date,
    YEAR(o.order_purchase_timestamp)
        AS purchase_year,
    MONTH(o.order_purchase_timestamp)
        AS purchase_month_number,

    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown Category'
    ) AS product_category,

    oi.price AS product_revenue,
    oi.freight_value AS freight_revenue,

    CASE
        WHEN oi.price < 50 THEN '1. Budget'
        WHEN oi.price < 100 THEN '2. Lower Mid-Range'
        WHEN oi.price < 200 THEN '3. Mid-Range'
        WHEN oi.price < 500 THEN '4. Premium'
        ELSE '5. Luxury'
    END AS price_segment

FROM order_items AS oi

INNER JOIN orders AS o
    ON oi.order_id = o.order_id

INNER JOIN products AS p
    ON oi.product_id = p.product_id

LEFT JOIN product_category_translation AS pct
    ON p.product_category_name = pct.product_category_name

WHERE o.order_status = 'delivered';


-- =====================================================
-- POWER BI PRODUCT FACT VIEW VALIDATION
-- Validate item-level uniqueness and revenue consistency
-- Compare product totals with the order-level fact view
-- =====================================================

SELECT
    COUNT(*) AS total_items,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(
        DISTINCT order_id, order_item_id
    ) AS distinct_order_items,
    COUNT(*) - COUNT(
        DISTINCT order_id, order_item_id
    ) AS duplicate_items,
    ROUND(SUM(product_revenue), 2)
        AS product_revenue,
    ROUND(SUM(freight_revenue), 2)
        AS freight_revenue,
    ROUND(SUM(product_revenue + freight_revenue), 2)
        AS total_order_value,
    COUNT(DISTINCT product_id) AS distinct_products,
    COUNT(DISTINCT product_category)
        AS distinct_categories
FROM pbi_fact_order_items;


-- =====================================================
-- POWER BI FACT REVENUE RECONCILIATION
-- Compare order-level and item-level financial totals
-- Verify consistent revenue across reporting datasets
-- =====================================================

WITH order_totals AS (
    SELECT
        COUNT(*) AS delivered_orders,
        ROUND(SUM(product_revenue), 2)
            AS product_revenue,
        ROUND(SUM(freight_revenue), 2)
            AS freight_revenue
    FROM pbi_fact_orders
),
item_totals AS (
    SELECT
        COUNT(DISTINCT order_id) AS delivered_orders,
        ROUND(SUM(product_revenue), 2)
            AS product_revenue,
        ROUND(SUM(freight_revenue), 2)
            AS freight_revenue
    FROM pbi_fact_order_items
)

SELECT
    o.delivered_orders AS order_fact_orders,
    i.delivered_orders AS item_fact_orders,
    o.product_revenue AS order_fact_revenue,
    i.product_revenue AS item_fact_revenue,
    ROUND(
        o.product_revenue - i.product_revenue, 2
    ) AS product_revenue_difference,
    ROUND(
        o.freight_revenue - i.freight_revenue, 2
    ) AS freight_revenue_difference
FROM order_totals AS o
CROSS JOIN item_totals AS i;


-- =====================================================
-- CREATE POWER BI CUSTOMER FACT VIEW
-- One row per unique delivered customer
-- Aggregate customer purchasing and revenue behavior
-- Support customer segmentation and repeat analysis
-- =====================================================

CREATE OR REPLACE VIEW pbi_fact_customers AS
SELECT
    customer_unique_id,
    COUNT(*) AS delivered_orders,
    ROUND(SUM(product_revenue), 2)
        AS total_product_revenue,
    ROUND(SUM(freight_revenue), 2)
        AS total_freight_revenue,
    ROUND(AVG(product_revenue), 2)
        AS average_order_value,
    MIN(purchase_date) AS first_purchase_date,
    MAX(purchase_date) AS last_purchase_date,

    CASE
        WHEN COUNT(*) = 1 THEN 'One-Time'
        ELSE 'Repeat'
    END AS customer_type

FROM pbi_fact_orders
GROUP BY customer_unique_id;


-- =====================================================
-- POWER BI CUSTOMER FACT VIEW VALIDATION
-- Validate customer-level uniqueness and financial totals
-- Reconcile customer counts and delivered orders
-- =====================================================

SELECT
    COUNT(*) AS total_customers,
    COUNT(DISTINCT customer_unique_id)
        AS distinct_customers,
    COUNT(*) - COUNT(DISTINCT customer_unique_id)
        AS duplicate_customers,
    SUM(delivered_orders) AS delivered_orders,
    SUM(customer_type = 'One-Time')
        AS one_time_customers,
    SUM(customer_type = 'Repeat')
        AS repeat_customers,
    ROUND(SUM(total_product_revenue), 2)
        AS product_revenue,
    ROUND(SUM(total_freight_revenue), 2)
        AS freight_revenue
FROM pbi_fact_customers;


-- =====================================================
-- CREATE POWER BI CUSTOMER RFM VIEW
-- Calculate recency, frequency, and monetary value
-- Use a fixed dataset-based reference date
-- =====================================================

CREATE OR REPLACE VIEW pbi_customer_rfm AS
WITH reference_date AS (
    SELECT
        DATE_ADD(
            MAX(purchase_date),
            INTERVAL 1 DAY
        ) AS analysis_date
    FROM pbi_fact_orders
)

SELECT
    c.customer_unique_id,
    c.delivered_orders AS frequency,
    c.total_product_revenue AS monetary_value,
    DATEDIFF(
        r.analysis_date,
        c.last_purchase_date
    ) AS recency_days,
    c.customer_type,
    c.first_purchase_date,
    c.last_purchase_date

FROM pbi_fact_customers AS c
CROSS JOIN reference_date AS r;


-- =====================================================
-- POWER BI CUSTOMER RFM VALIDATION
-- Verify unique customers and valid RFM metrics
-- Reconcile frequency and monetary totals
-- =====================================================

SELECT
    COUNT(*) AS total_customers,
    COUNT(DISTINCT customer_unique_id)
        AS distinct_customers,
    COUNT(*) - COUNT(DISTINCT customer_unique_id)
        AS duplicate_customers,
    SUM(frequency) AS delivered_orders,
    ROUND(SUM(monetary_value), 2)
        AS total_product_revenue,
    MIN(recency_days) AS minimum_recency,
    MAX(recency_days) AS maximum_recency,
    SUM(recency_days < 0) AS negative_recency,
    SUM(
        recency_days IS NULL
        OR frequency IS NULL
        OR monetary_value IS NULL
    ) AS incomplete_rfm_records
FROM pbi_customer_rfm;


-- =====================================================
-- CREATE POWER BI CUSTOMER SEGMENTATION VIEW
-- Apply the original RFM scoring methodology
-- Preserve the five validated customer segments
-- Support customer segmentation in Power BI
-- =====================================================

CREATE OR REPLACE VIEW pbi_customer_segments AS

WITH rfm_percentiles AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary_value,

        CUME_DIST() OVER (
            ORDER BY recency_days ASC
        ) AS recency_percentile,

        CUME_DIST() OVER (
            ORDER BY monetary_value ASC
        ) AS monetary_percentile

    FROM pbi_customer_rfm
),

rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary_value,

        6 - CEIL(recency_percentile * 5)
            AS r_score,

        LEAST(frequency, 5)
            AS f_score,

        CEIL(monetary_percentile * 5)
            AS m_score

    FROM rfm_percentiles
)

SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary_value,
    r_score,
    f_score,
    m_score,

    CASE
        WHEN frequency >= 2
             AND r_score >= 4
             AND m_score >= 4
            THEN 'Champions'

        WHEN frequency >= 2
             AND r_score >= 3
            THEN 'Loyal Customers'

        WHEN frequency >= 2
            THEN 'At-Risk Repeat'

        WHEN frequency = 1
             AND m_score >= 4
            THEN 'High-Value One-Time'

        ELSE 'Other One-Time'
    END AS customer_segment

FROM rfm_scores;


-- =====================================================
-- POWER BI CUSTOMER SEGMENTATION VALIDATION
-- Verify segment distribution and customer uniqueness
-- Reconcile revenue with the original RFM analysis
-- =====================================================

SELECT
    customer_segment,

    COUNT(*) AS customers,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct,

    ROUND(SUM(monetary_value), 2)
        AS product_revenue,

    ROUND(
        100.0 * SUM(monetary_value)
        / SUM(SUM(monetary_value)) OVER (),
        2
    ) AS revenue_share_pct,

    ROUND(AVG(recency_days), 2)
        AS avg_recency_days

FROM pbi_customer_segments

GROUP BY customer_segment

ORDER BY product_revenue DESC;


-- =====================================================
-- CREATE POWER BI DELIVERY RETENTION VIEW
-- Analyze first-order delivery and 90-day repeat purchase
-- Require a complete 90-day post-delivery follow-up
-- Preserve the original observational cohort definition
-- =====================================================

CREATE OR REPLACE VIEW pbi_delivery_retention AS

WITH analysis_date AS (
    SELECT
        MAX(order_purchase_timestamp)
            AS last_observed_purchase
    FROM orders
    WHERE order_status = 'delivered'
),

ranked_orders AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        f.product_revenue,

        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY
                o.order_purchase_timestamp,
                o.order_id
        ) AS purchase_number

    FROM orders AS o

    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id

    INNER JOIN pbi_fact_orders AS f
        ON o.order_id = f.order_id

    WHERE o.order_status = 'delivered'
),

eligible_first_orders AS (
    SELECT
        r.customer_unique_id,
        r.order_id AS first_order_id,

        DATE(r.order_purchase_timestamp)
            AS first_purchase_date,

        YEAR(r.order_purchase_timestamp)
            AS purchase_year,

        r.order_delivered_customer_date
            AS first_delivery_timestamp,

        r.product_revenue
            AS first_order_product_revenue,

        CASE
            WHEN DATE(r.order_delivered_customer_date)
                 > DATE(r.order_estimated_delivery_date)
                THEN 'Late'
            ELSE 'On-Time'
        END AS delivery_performance

    FROM ranked_orders AS r

    CROSS JOIN analysis_date AS a

    WHERE r.purchase_number = 1

      AND r.order_delivered_customer_date IS NOT NULL

      AND r.order_estimated_delivery_date IS NOT NULL

      AND r.order_delivered_customer_date
          >= r.order_purchase_timestamp

      AND r.order_delivered_customer_date <=
          DATE_SUB(
              a.last_observed_purchase,
              INTERVAL 90 DAY
          )
)

SELECT
    f.customer_unique_id,
    f.first_order_id,
    f.first_purchase_date,
    f.purchase_year,
    DATE(f.first_delivery_timestamp)
        AS first_delivery_date,
    f.first_order_product_revenue,
    f.delivery_performance,

    MAX(
        CASE
            WHEN r.purchase_number > 1

             AND r.order_purchase_timestamp >
                 f.first_delivery_timestamp

             AND r.order_purchase_timestamp <=
                 DATE_ADD(
                     f.first_delivery_timestamp,
                     INTERVAL 90 DAY
                 )

                THEN 1
            ELSE 0
        END
    ) AS repeated_within_90_days

FROM eligible_first_orders AS f

INNER JOIN ranked_orders AS r
    ON f.customer_unique_id = r.customer_unique_id

GROUP BY
    f.customer_unique_id,
    f.first_order_id,
    f.first_purchase_date,
    f.purchase_year,
    f.first_delivery_timestamp,
    f.first_order_product_revenue,
    f.delivery_performance;


-- =====================================================
-- POWER BI DELIVERY RETENTION VALIDATION
-- Verify eligible customers and 90-day repeat outcomes
-- Reconcile delivery groups with the original analysis
-- =====================================================

SELECT
    delivery_performance,

    COUNT(*) AS eligible_customers,

    COUNT(DISTINCT customer_unique_id)
        AS distinct_customers,

    SUM(repeated_within_90_days)
        AS repeat_customers_90d,

    ROUND(
        100.0 * SUM(repeated_within_90_days)
        / COUNT(*),
        4
    ) AS repeat_rate_90d_pct

FROM pbi_delivery_retention

GROUP BY delivery_performance

ORDER BY delivery_performance;


-- =====================================================
-- DELIVERY RETENTION SOURCE RECONCILIATION
-- Compare delivered orders against the reporting fact
-- Identify orders excluded by the fact table join
-- =====================================================

SELECT
    COUNT(*) AS delivered_orders,

    COUNT(f.order_id)
        AS orders_in_fact_view,

    SUM(f.order_id IS NULL)
        AS orders_missing_from_fact,

    COUNT(DISTINCT c.customer_unique_id)
        AS delivered_customers,

    COUNT(
        DISTINCT CASE
            WHEN f.order_id IS NULL
                THEN c.customer_unique_id
        END
    ) AS customers_with_missing_fact_orders

FROM orders AS o

INNER JOIN customers AS c
    ON o.customer_id = c.customer_id

LEFT JOIN pbi_fact_orders AS f
    ON o.order_id = f.order_id

WHERE o.order_status = 'delivered';


-- =====================================================
-- DELIVERY RETENTION FIRST PURCHASE YEAR VALIDATION
-- Inspect first delivered orders by purchase year
-- Identify potential exclusions from the cohort
-- =====================================================

WITH ranked_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,

        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY
                o.order_purchase_timestamp,
                o.order_id
        ) AS purchase_number

    FROM orders AS o

    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id

    WHERE o.order_status = 'delivered'
)

SELECT
    YEAR(order_purchase_timestamp)
        AS first_purchase_year,

    COUNT(*) AS first_delivered_orders,

    SUM(
        order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
        AND order_delivered_customer_date
            >= order_purchase_timestamp
    ) AS valid_delivery_records

FROM ranked_orders

WHERE purchase_number = 1

GROUP BY YEAR(order_purchase_timestamp)

ORDER BY first_purchase_year;


-- =====================================================
-- POWER BI DELIVERY RETENTION VALIDATION
-- Verify eligible customers and 90-day repeat outcomes
-- Reconcile delivery groups with the original analysis
-- =====================================================

SELECT
    delivery_performance,
    COUNT(*) AS eligible_customers,
    COUNT(DISTINCT customer_unique_id)
        AS distinct_customers,
    SUM(repeated_within_90_days)
        AS repeat_customers_90d,
    ROUND(
        100.0 * SUM(repeated_within_90_days)
        / COUNT(*),
        4
    ) AS repeat_rate_90d_pct
FROM pbi_delivery_retention
GROUP BY delivery_performance
ORDER BY delivery_performance;
