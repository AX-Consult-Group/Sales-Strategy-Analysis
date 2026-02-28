-- ============================================================
-- Project  : Scale Model Car Store — Sales Strategy Analysis
-- Database : stores.db  (SQLite)
-- Author   : Jurgen B.
-- Purpose  : Analyse inventory, product performance and customer
--            value to inform sales and restocking decisions.
-- ============================================================

-- ============================================================
-- DATABASE OVERVIEW
-- ============================================================
-- The stores.db database contains eight related tables:
--
--   customers    – Customer records (PK: customerNumber)
--                  Links to: orders, payments, employees
--   employees    – Employee records (PK: employeeNumber)
--                  Links to: offices; self-references via reportsTo
--   offices      – Sales office details (PK: officeCode)
--   orders       – Customer order headers (PK: orderNumber)
--                  Links to: orderdetails
--   orderdetails – Individual order line items (PK: orderNumber)
--                  Links to: products
--   payments     – Customer payment records (PK: checkNumber)
--   products     – Scale-model product catalogue (PK: productCode)
--                  Links to: productlines
--   productlines – Product category definitions (PK: productLine)
-- ============================================================


-- ============================================================
-- SECTION 1: Database Summary
-- Overview of every table: column count and row count.
-- ============================================================

SELECT 'Customers'    AS table_name,
       COUNT(*)       AS number_of_attributes,
       (SELECT COUNT(*) FROM customers)    AS number_of_rows
  FROM PRAGMA_TABLE_INFO('customers')

UNION ALL

SELECT 'Products'     AS table_name,
       COUNT(*)       AS number_of_attributes,
       (SELECT COUNT(*) FROM products)     AS number_of_rows
  FROM PRAGMA_TABLE_INFO('products')

UNION ALL

SELECT 'ProductLines' AS table_name,
       COUNT(*)       AS number_of_attributes,
       (SELECT COUNT(*) FROM productlines) AS number_of_rows
  FROM PRAGMA_TABLE_INFO('productlines')

UNION ALL

SELECT 'Orders'       AS table_name,
       COUNT(*)       AS number_of_attributes,
       (SELECT COUNT(*) FROM orders)       AS number_of_rows
  FROM PRAGMA_TABLE_INFO('orders')

UNION ALL

SELECT 'OrderDetails' AS table_name,
       COUNT(*)       AS number_of_attributes,
       (SELECT COUNT(*) FROM orderdetails) AS number_of_rows
  FROM PRAGMA_TABLE_INFO('orderdetails')

UNION ALL

SELECT 'Payments'     AS table_name,
       COUNT(*)       AS number_of_attributes,
       (SELECT COUNT(*) FROM payments)     AS number_of_rows
  FROM PRAGMA_TABLE_INFO('payments')

UNION ALL

SELECT 'Employees'    AS table_name,
       COUNT(*)       AS number_of_attributes,
       (SELECT COUNT(*) FROM employees)    AS number_of_rows
  FROM PRAGMA_TABLE_INFO('employees')

UNION ALL

SELECT 'Offices'      AS table_name,
       COUNT(*)       AS number_of_attributes,
       (SELECT COUNT(*) FROM offices)      AS number_of_rows
  FROM PRAGMA_TABLE_INFO('offices');


-- ============================================================
-- SECTION 2: Inventory Analysis — Low Stock Products
-- Business question: Which products should we order more of?
-- Low stock ratio = total units ordered / units currently in stock.
-- A higher ratio means the product is selling faster than stock
-- is being replenished.
-- ============================================================

SELECT productCode,
       ROUND(
           (SELECT SUM(quantityOrdered) * 1.0
              FROM orderdetails od
             WHERE od.productCode = p.productCode)
           / quantityInStock,
       2) AS low_stock_ratio
  FROM products p
 GROUP BY productCode
 ORDER BY low_stock_ratio DESC
 LIMIT 10;


-- ============================================================
-- SECTION 3: Product Performance — Revenue by Product
-- Business question: Which products generate the most revenue?
-- ============================================================

SELECT productCode,
       (SELECT SUM(quantityOrdered * priceEach)
          FROM orderdetails od
         WHERE od.productCode = p.productCode) AS product_performance
  FROM products p
 GROUP BY productCode
 ORDER BY product_performance DESC;


-- ============================================================
-- SECTION 4: Priority Restock List (CTE)
-- Business question: Which high-revenue products are also low
-- in stock? These are the products that need urgent restocking.
--
-- Approach: Use two CTEs.
--   1. low_stock_cte      – top 10 products by low-stock ratio.
--   2. product_performance_cte – top 10 products by revenue,
--                                filtered to the low-stock list.
-- ============================================================

WITH low_stock_cte AS (
    SELECT productCode,
           ROUND(
               (SELECT SUM(quantityOrdered) * 1.0
                  FROM orderdetails od
                 WHERE od.productCode = p.productCode)
               / quantityInStock,
           2) AS low_stock_ratio
      FROM products p
     GROUP BY productCode
     ORDER BY low_stock_ratio DESC
     LIMIT 10
),

product_performance_cte AS (
    SELECT productCode,
           SUM(quantityOrdered * priceEach) AS product_performance
      FROM orderdetails
     WHERE productCode IN (SELECT productCode FROM low_stock_cte)
     GROUP BY productCode
     ORDER BY product_performance DESC
     LIMIT 10
)

SELECT p.productCode,
       p.productName,
       p.productLine
  FROM products p
 WHERE productCode IN (SELECT productCode FROM product_performance_cte);


-- ============================================================
-- SECTION 5: Low Stock with Product Names (Temp Table)
-- Using a temporary table to make the low-stock query reusable
-- across multiple subsequent SELECT statements.
-- ============================================================

-- Step 1: Create the temporary table (run once per session).
CREATE TEMP TABLE IF NOT EXISTS temp_low_stock AS
    SELECT productCode,
           ROUND(SUM(quantityOrdered) * 1.0 / quantityInStock, 2) AS low_stock_ratio
      FROM products p
      JOIN orderdetails od USING (productCode)
     GROUP BY productCode;

-- Step 2: Query the temp table with product names.
SELECT p.productName,
       t.low_stock_ratio
  FROM products p
  JOIN temp_low_stock t ON p.productCode = t.productCode
 ORDER BY t.low_stock_ratio DESC;


-- ============================================================
-- SECTION 6: Customer Sales Volume
-- Business question: Which customers buy the most units?
-- Joins orders, orderdetails and products to compute total
-- units sold per customer.
-- ============================================================

SELECT o.customerNumber,
       SUM(od.quantityOrdered)         AS total_units_ordered,
       od.productCode,
       p.productName
  FROM orders AS o
  JOIN orderdetails AS od ON od.orderNumber  = o.orderNumber
  JOIN products     AS p  ON p.productCode   = od.productCode
 GROUP BY o.customerNumber
 ORDER BY total_units_ordered DESC;


-- ============================================================
-- SECTION 7: Profit per Customer
-- Business question: Which customers are the most profitable?
-- Profit = (priceEach - buyPrice) × quantityOrdered
-- ============================================================

SELECT o.customerNumber,
       SUM(od.quantityOrdered)                              AS total_units_ordered,
       od.productCode,
       p.productName,
       ROUND(SUM(od.quantityOrdered * (od.priceEach - p.buyPrice)), 2) AS profit
  FROM orders AS o
  JOIN orderdetails AS od ON od.orderNumber = o.orderNumber
  JOIN products     AS p  ON p.productCode  = od.productCode
 GROUP BY o.customerNumber
 ORDER BY profit DESC;


-- ============================================================
-- SECTION 8: VIP Customer Identification
-- Business question: Who are our top 10 most valuable customers,
-- and how do we contact them for a targeted marketing campaign?
-- Extends Section 7 by joining the customers table to retrieve
-- name, contact details, city and country.
-- ============================================================

SELECT o.customerNumber,
       c.customerName,
       c.contactFirstName,
       c.contactLastName,
       c.city,
       c.country,
       ROUND(SUM(od.quantityOrdered * (od.priceEach - p.buyPrice)), 2) AS profit
  FROM orders AS o
  JOIN customers    AS c  ON c.customerNumber = o.customerNumber
  JOIN orderdetails AS od ON od.orderNumber   = o.orderNumber
  JOIN products     AS p  ON p.productCode    = od.productCode
 GROUP BY o.customerNumber
 ORDER BY profit DESC
 LIMIT 10;

-- ============================================================
-- End of analysis
-- ============================================================
