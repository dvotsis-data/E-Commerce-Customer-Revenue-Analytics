
# Dataset

## Source

This project uses the [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), available on Kaggle.

The dataset contains historical Brazilian e-commerce transactions, including customer information, orders, products, payments, sellers, reviews, and delivery details.

## Source Files

The original dataset consists of nine CSV files:

| File | Description |
| --- | --- |
| `olist_customers_dataset.csv` | Customer identifiers and geographic information |
| `olist_geolocation_dataset.csv` | Geographic coordinates and ZIP code information |
| `olist_order_items_dataset.csv` | Products, sellers, prices, and freight values associated with orders |
| `olist_order_payments_dataset.csv` | Payment methods, installments, and payment amounts |
| `olist_order_reviews_dataset.csv` | Customer reviews and satisfaction scores |
| `olist_orders_dataset.csv` | Order status, purchase dates, and delivery timestamps |
| `olist_products_dataset.csv` | Product categories and product attributes |
| `olist_sellers_dataset.csv` | Seller identifiers and locations |
| `product_category_name_translation.csv` | English translations of product category names |

## Data Availability

The original CSV files are not included in this repository to avoid duplicating the publicly available dataset.

To reproduce the analysis:

1. Download the dataset from the Kaggle link above.
2. Extract the CSV files.
3. Place them in the following local directory:

   `01_Data/Raw/`

4. Open `02_SQL/02_import_data.sql`.
5. Replace `PATH_TO_PROJECT` with the appropriate local project path.
6. Execute the SQL scripts according to the instructions in the main project README.

## Data Processing

Data validation and analytical transformations are performed using MySQL.

The relevant SQL scripts are available in the [`02_SQL`](../02_SQL/) directory.

The data quality findings and handling decisions are documented in [`04_data_quality_summary.md`](../02_SQL/04_data_quality_summary.md).

The Power BI report uses analysis-ready data derived from the SQL workflow.
