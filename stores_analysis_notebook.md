# Scale Model Car Store — SQL Analysis Notebook

**Database:** `stores.db` (SQLite) &nbsp;|&nbsp; **Author:** Jurgen B. &nbsp;|&nbsp; **Tool:** VS Code + SQLite (alexcvzz)

> This notebook combines SQL code, explanations and live query output in a single document.
> The goal is to analyse inventory, product performance and customer value to inform sales strategy.

---

## Database Schema

The database contains **8 related tables** covering customers, employees, offices, orders, products and payments.

```
productlines ──► products ──► orderdetails ──► orders ──► customers
                                                               │
                                                           payments
employees ──► offices
```

---

## Section 1 — Database Overview

**Goal:** Compile a summary of every table — how many columns and rows each one has.

**Techniques:** `UNION ALL`, `PRAGMA_TABLE_INFO`, `COUNT`, subqueries

```sql
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
```

**Output:**

| Table Name | Columns | Rows |
|---|---|---|
| Customers | 13 | 122 |
| Products | 9 | 110 |
| ProductLines | 4 | 7 |
| Orders | 7 | 326 |
| OrderDetails | 5 | 2,996 |
| Payments | 4 | 273 |
| Employees | 8 | 23 |
| Offices | 9 | 7 |

---

## Section 2 — Low Stock Analysis

**Business question:** Which products should we order more of?

**Approach:** Calculate a **low stock ratio** for each product:

> `low_stock_ratio = total units ever ordered ÷ units currently in stock`

A higher ratio means the product is selling faster than it is being replenished.

**Techniques:** Correlated subquery, `ROUND`, `GROUP BY`, `ORDER BY`, `LIMIT`

```sql
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
```

**Output:**

| Product Code | Product Name | Low Stock Ratio |
|---|---|---|
| S24_2000 | 1960 BSA Gold Star DBD34 | 67.67 |
| S12_1099 | 1968 Ford Mustang | 13.72 |
| S32_4289 | 1928 Ford Phaeton Deluxe | 7.15 |
| S32_1374 | 1997 BMW F650 ST | 5.70 |
| S72_3212 | Pont Yacht | 2.31 |
| S700_3167 | F/A 18 Hornet 1/72 | 1.90 |
| S50_4713 | 2002 Yamaha YZR M1 | 1.65 |
| S18_2795 | 1928 Mercedes-Benz SSK | 1.61 |
| S18_2248 | 1911 Ford Town Car | 1.54 |
| S700_1938 | The Mayflower | 1.22 |

> **Finding:** The 1960 BSA Gold Star DBD34 has a ratio of 67.67 — meaning over 67× more units have been ordered historically than are currently in stock. This is a critical restock priority.

---

## Section 3 — Product Performance by Revenue

**Business question:** Which products generate the most revenue?

**Approach:** Calculate total revenue per product:

> `product_performance = SUM(quantityOrdered × priceEach)`

**Techniques:** Correlated subquery, `SUM`, `GROUP BY`, `ORDER BY`

```sql
SELECT productCode,
       (SELECT SUM(quantityOrdered * priceEach)
          FROM orderdetails od
         WHERE od.productCode = p.productCode) AS product_performance
  FROM products p
 GROUP BY productCode
 ORDER BY product_performance DESC;
```

**Output (Top 10):**

| Product Code | Product Name | Revenue |
|---|---|---|
| S18_3232 | 1992 Ferrari 360 Spider red | $276,839.98 |
| S12_1108 | 2001 Ferrari Enzo | $190,755.86 |
| S10_1949 | 1952 Alpine Renault 1300 | $190,017.96 |
| S10_4698 | 2003 Harley-Davidson Eagle Drag Bike | $170,686.00 |
| S12_1099 | 1968 Ford Mustang | $161,531.48 |
| S12_3891 | 1969 Ford Falcon | $152,543.02 |
| S18_1662 | 1980s Black Hawk Helicopter | $144,959.91 |
| S18_2238 | 1998 Chrysler Plymouth Prowler | $142,530.63 |
| S18_1749 | 1917 Grand Touring Sedan | $140,535.60 |
| S12_2823 | 2002 Suzuki XREO | $135,767.03 |

---

## Section 4 — Priority Restock List (CTE)

**Business question:** Which products are *both* high-revenue *and* critically low in stock?

**Approach:** Use two CTEs chained together:
- `low_stock_cte` — top 10 products by low stock ratio
- `product_performance_cte` — top 10 revenue products, filtered to the low-stock list

This gives the final priority restock list: products that sell well *and* need urgent restocking.

**Techniques:** Common Table Expressions (`WITH … AS`), nested `IN` subquery, multi-step filtering

```sql
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
```

**Output:**

| Product Code | Product Name | Product Line |
|---|---|---|
| S12_1099 | 1968 Ford Mustang | Classic Cars |
| S18_2248 | 1911 Ford Town Car | Vintage Cars |
| S18_2795 | 1928 Mercedes-Benz SSK | Vintage Cars |
| S24_2000 | 1960 BSA Gold Star DBD34 | Motorcycles |
| S32_1374 | 1997 BMW F650 ST | Motorcycles |
| S32_4289 | 1928 Ford Phaeton Deluxe | Vintage Cars |
| S50_4713 | 2002 Yamaha YZR M1 | Motorcycles |
| S700_1938 | The Mayflower | Ships |
| S700_3167 | F/A 18 Hornet 1/72 | Planes |
| S72_3212 | Pont Yacht | Ships |

> **Finding:** 10 products meet both criteria — they are top revenue generators AND critically understocked. These should be the first to be reordered.

---

## Section 5 — Low Stock with Product Names (Temp Table)

**Goal:** Reproduce the low stock list with product names, using a reusable temporary table instead of a correlated subquery — a more efficient approach for repeated queries.

**Techniques:** `CREATE TEMP TABLE`, `JOIN`, `USING`

```sql
-- Step 1: Create the temporary table (run once per session)
CREATE TEMP TABLE IF NOT EXISTS temp_low_stock AS
    SELECT productCode,
           ROUND(SUM(quantityOrdered) * 1.0 / quantityInStock, 2) AS low_stock_ratio
      FROM products p
      JOIN orderdetails od USING (productCode)
     GROUP BY productCode;

-- Step 2: Query with product names
SELECT p.productName,
       t.low_stock_ratio
  FROM products p
  JOIN temp_low_stock t ON p.productCode = t.productCode
 ORDER BY t.low_stock_ratio DESC;
```

**Output (Top 10):**

| Product Name | Low Stock Ratio |
|---|---|
| 1960 BSA Gold Star DBD34 | 67.67 |
| 1968 Ford Mustang | 13.72 |
| 1928 Ford Phaeton Deluxe | 7.15 |
| 1997 BMW F650 ST | 5.70 |
| Pont Yacht | 2.31 |
| F/A 18 Hornet 1/72 | 1.90 |
| 2002 Yamaha YZR M1 | 1.65 |
| 1928 Mercedes-Benz SSK | 1.61 |
| 1911 Ford Town Car | 1.54 |
| The Mayflower | 1.22 |

---

## Section 6 — Customer Sales Volume

**Business question:** Which customers buy the most units overall?

**Approach:** Join orders, orderdetails and products to sum up total units ordered per customer.

**Techniques:** Multi-table `JOIN`, `SUM`, `GROUP BY`, `ORDER BY`

```sql
SELECT o.customerNumber,
       SUM(od.quantityOrdered)         AS total_units_ordered,
       od.productCode,
       p.productName
  FROM orders AS o
  JOIN orderdetails AS od ON od.orderNumber  = o.orderNumber
  JOIN products     AS p  ON p.productCode   = od.productCode
 GROUP BY o.customerNumber
 ORDER BY total_units_ordered DESC;
```

**Output (Top 10):**

| Customer No. | Total Units Ordered | Top Product |
|---|---|---|
| 141 | 9,327 | 1969 Corvair Monza |
| 124 | 6,366 | 1958 Setra Bus |
| 114 | 1,926 | 1996 Moto Guzzi 1100i |
| 119 | 1,832 | 1969 Harley Davidson Ultimate Chopper |
| 187 | 1,778 | 1965 Aston Martin DB5 |
| 151 | 1,775 | 2001 Ferrari Enzo |
| 323 | 1,691 | F/A 18 Hornet 1/72 |
| 450 | 1,656 | 1980s Black Hawk Helicopter |
| 278 | 1,650 | 1980s Black Hawk Helicopter |
| 496 | 1,647 | 1917 Grand Touring Sedan |

---

## Section 7 — Profit per Customer

**Business question:** Which customers are the most *profitable* (not just the highest volume)?

**Approach:** Calculate profit per customer:

> `profit = SUM(quantityOrdered × (priceEach − buyPrice))`

**Techniques:** Arithmetic on columns, multi-table `JOIN`, `ROUND`, `SUM`

```sql
SELECT o.customerNumber,
       SUM(od.quantityOrdered)                                         AS total_units_ordered,
       od.productCode,
       p.productName,
       ROUND(SUM(od.quantityOrdered * (od.priceEach - p.buyPrice)), 2) AS profit
  FROM orders AS o
  JOIN orderdetails AS od ON od.orderNumber = o.orderNumber
  JOIN products     AS p  ON p.productCode  = od.productCode
 GROUP BY o.customerNumber
 ORDER BY profit DESC;
```

**Output (Top 10):**

| Customer No. | Total Units | Profit |
|---|---|---|
| 141 | 9,327 | $326,519.66 |
| 124 | 6,366 | $236,769.39 |
| 151 | 1,775 | $72,370.09 |
| 114 | 1,926 | $70,311.07 |
| 119 | 1,832 | $60,875.30 |
| 148 | 1,524 | $60,477.38 |
| 187 | 1,778 | $60,095.86 |
| 323 | 1,691 | $60,013.99 |
| 131 | 1,631 | $58,669.10 |
| 450 | 1,656 | $55,931.37 |

---

## Section 8 — VIP Customer Identification

**Business question:** Who are our top 10 most valuable customers and how do we reach them?

**Approach:** Extend the profit query by joining the `customers` table to retrieve full name, city and country — enabling a targeted VIP marketing campaign.

**Techniques:** 4-table `JOIN`, `GROUP BY`, `ORDER BY`, `LIMIT`

```sql
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
```

**Output:**

| Rank | Customer | Contact | City | Country | Profit |
|---|---|---|---|---|---|
| 1 | Euro+ Shopping Channel | Diego Freyre | Madrid | Spain | $326,519.66 |
| 2 | Mini Gifts Distributors Ltd. | Susan Nelson | San Rafael | USA | $236,769.39 |
| 3 | Muscle Machine Inc | Jeff Young | NYC | USA | $72,370.09 |
| 4 | Australian Collectors, Co. | Peter Ferguson | Melbourne | Australia | $70,311.07 |
| 5 | La Rochelle Gifts | Janine Labrune | Nantes | France | $60,875.30 |
| 6 | Dragon Souveniers, Ltd. | Eric Natividad | Singapore | Singapore | $60,477.38 |
| 7 | AV Stores, Co. | Rachel Ashworth | Manchester | UK | $60,095.86 |
| 8 | Down Under Souveniers, Inc | Mike Graham | Auckland | New Zealand | $60,013.99 |
| 9 | Land of Toys Inc. | Kwai Lee | NYC | USA | $58,669.10 |
| 10 | The Sharp Gifts Warehouse | Sue Frick | San Jose | USA | $55,931.37 |

> **Recommendation:** These 10 customers account for a disproportionate share of total profit. A dedicated VIP outreach campaign targeting these contacts directly is strongly recommended.

---

## Summary of SQL Techniques Used

| Technique | Sections |
|---|---|
| `SELECT`, `WHERE`, `GROUP BY`, `ORDER BY` | All |
| `UNION ALL` | 1 |
| `PRAGMA_TABLE_INFO` | 1 |
| Correlated subqueries | 2, 3 |
| Common Table Expressions (`WITH … AS`) | 4 |
| `CREATE TEMP TABLE` | 5 |
| `JOIN` — multi-table (3–4 tables) | 6, 7, 8 |
| `JOIN … USING` | 5 |
| Arithmetic on columns (`priceEach − buyPrice`) | 7, 8 |
| `ROUND`, `SUM`, `COUNT` | Throughout |
| `LIMIT` | 2, 4, 8 |

---

*Analysis performed on `stores.db` — a scale model car retailer dataset.*
