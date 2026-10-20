
# Data Quality Assessment Report

## Project Overview

**Project:** End-to-End E-Commerce Customer & Revenue Analytics  
**Dataset:** Olist Brazilian E-Commerce Public Dataset  
**Database:** MySQL 8.0  
**Assessment Scope:** 9 relational tables, 39 SQL data quality checks

## 1. Objective

The objective of this assessment is to evaluate the completeness, validity, consistency, and relational integrity of the Olist e-commerce dataset before performing customer, revenue, product, and delivery analytics.

The assessment identifies potential data quality issues, evaluates their business impact, and defines appropriate handling strategies without modifying the original source data.

## 2. Dataset Overview

| Table | Records |
|---|---:|
| customers | 99,441 |
| orders | 99,441 |
| order_items | 112,650 |
| products | 32,951 |
| order_payments | 103,886 |
| order_reviews | 99,224 |
| sellers | 3,095 |
| geolocation | 1,000,163 |
| product_category_translation | 73 |

## 3. Key Data Quality Findings

### 3.1 Missing Values

- **Orders:** 160 missing approval timestamps, 1,783 missing carrier handoff timestamps, and 2,965 missing customer delivery timestamps.
- **Delivered orders:** 8 orders marked as delivered have no actual delivery timestamp.
- **Products:** 610 products have missing category, name length, description length, and photo quantity information.
- **Product dimensions:** 2 products have missing weight and dimension values; 4 additional products have zero weight.
- **Reviews:** 87,656 reviews have no comment title, and 58,247 have no comment message.
- **Customers, sellers, payments, and geolocation:** No NULL values were found in the attributes tested.

**Handling strategy:** Preserve the original records. Use an "Unknown Category" label for missing product categories and exclude missing values only from analyses requiring the affected attributes.

### 3.2 Financial Data Validation

- No negative product prices, freight charges, or payment amounts were identified.
- 383 order items have zero freight charges.
- 9 payment records have a zero payment amount.
- 2 credit card payment records have zero installments.
- 1 delivered order has no associated payment record, despite having an order value of R$ 143.46.

**Handling strategy:** Preserve financial records and distinguish missing payment information from genuine zero-value payments.

### 3.3 Order and Payment Reconciliation

A comparison of item totals (product price plus freight) against recorded payments produced the following results:

| Metric | Result |
|---|---:|
| Orders with items and payments | 98,665 |
| Matching orders | 98,362 |
| Mismatched orders | 303 |
| Mismatch rate | 0.31% |
| Maximum absolute difference | R$ 182.81 |

Of the 303 mismatched orders:

- 264 have payments exceeding their calculated order value, totaling R$ 3,070.14 in positive differences.
- 39 have payments below their calculated order value, totaling R$ 199.08 in negative differences.
- The net discrepancy is R$ 2,871.06.

**Handling strategy:** Keep product value, freight value, and recorded payment value as separate financial measures. Do not overwrite or artificially reconcile source amounts.

### 3.4 Referential Integrity

- All 112,650 order item records match an existing product.
- All 112,650 order item records match an existing seller.
- 775 orders have no associated order items, primarily orders marked as unavailable or canceled.
- 1 delivered order has no corresponding payment record.
- All non-NULL product categories have an English translation.

**Handling strategy:** Use appropriate join types and clearly defined order-status filters to prevent unintended record loss.

### 3.5 Geographic Data Quality

The geolocation table contains:

- 1,000,163 geographic records.
- 19,015 distinct ZIP code prefixes.
- 17,972 ZIP code prefixes appearing more than once.
- 42 records outside the approximate geographic bounds used for Brazil.

Of these 42 records, 11 correspond to Fernando de Noronha, a legitimate Brazilian island location outside the simplified bounding box.

The remaining 31 records contain potentially inconsistent coordinates requiring further validation.

**Handling strategy:** Avoid direct many-to-many joins between customer records and raw geolocation records. Create a ZIP-code-level reference table for geographic analysis and validate suspicious coordinates before mapping.

### 3.6 Timestamp Consistency

The assessment identified:

- 166 orders with carrier handoff timestamps preceding purchase timestamps.
- 23 orders with customer delivery timestamps preceding carrier handoff timestamps.
- No orders with approval timestamps preceding purchase timestamps.
- No orders with customer delivery timestamps preceding purchase timestamps.

Of the 166 carrier-before-purchase anomalies:

- 121 have a discrepancy of up to one hour.
- 43 have a discrepancy between one and three hours.
- 2 have a discrepancy exceeding 24 hours.

**Handling strategy:** Exclude negative time intervals from the specific delivery-duration metrics they affect, while retaining otherwise valid orders for revenue analysis.

### 3.7 Delivery Performance

| Metric | Result |
|---|---:|
| Orders marked as delivered | 96,478 |
| Delivered orders with actual delivery date | 96,470 |
| Late deliveries | 7,826 |
| Late delivery rate | 8.11% |

Approximately 91.89% of delivered orders with available delivery timestamps arrived on or before their estimated delivery date.

**Handling strategy:** Calculate delivery KPIs using clearly defined eligible order populations and document exclusions caused by missing or inconsistent timestamps.

## 4. Data Transformation Recommendations

Based on the assessment, the following practices will be applied during subsequent analytics:

1. Preserve raw source tables and avoid destructive corrections.
2. Use explicit business definitions for revenue, freight, payments, and order counts.
3. Retain products with missing categories under an "Unknown Category" label.
4. Aggregate order items and payments separately before joining them at the order level.
5. Build a ZIP-code-level geographic reference to prevent duplicated records in joins.
6. Exclude invalid durations only from calculations affected by those anomalies.
7. Document all analytical filters and assumptions for reproducibility.

## 5. Conclusion

The Olist dataset is suitable for further customer, revenue, product, and delivery analytics, provided that the identified data quality issues are handled consistently.

The assessment found strong product and seller referential integrity, a high level of financial reconciliation, and mostly complete core transactional attributes.

The next project phase will focus on SQL-based data transformation and business analysis, followed by Python analytics and Power BI reporting.
