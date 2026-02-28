# Scale Model Car Store — Sales Strategy Analysis

A SQL-based data analysis project using a relational database of a scale model car retailer. The goal is to answer key business questions around inventory management, product performance and customer value — ultimately informing the company's sales and restocking strategy.

---

## Database Overview

**File:** `stores.db` (SQLite) — 8 tables, ~4,100 rows total.

| Table | Description | Rows | Columns |
|---|---|---|---|
| `customers` | Customer records | 122 | 13 |
| `employees` | Employee records | 23 | 8 |
| `offices` | Sales office locations | 7 | 9 |
| `orders` | Order headers | 326 | 7 |
| `orderdetails` | Individual order line items | 2,996 | 5 |
| `payments` | Customer payment records | 273 | 4 |
| `products` | Scale-model product catalogue | 110 | 9 |
| `productlines` | Product category definitions | 7 | 4 |

### Entity Relationships

```
productlines ←── products ←── orderdetails ──→ orders ──→ customers
                                                               ↑
                                                           payments
                                                           employees ──→ offices
```

---

## Business Questions & Analysis

### 1. Which products should we restock urgently?

A **low stock ratio** is calculated for each product as:

> `low_stock_ratio = total units ever ordered / units currently in stock`

A high ratio indicates a product is selling fast relative to available stock.

**Top 10 low-stock products:**

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

### 2. Which products are the highest performers by revenue?

Product performance is measured as total revenue generated:

> `product_performance = SUM(quantityOrdered × priceEach)`

---

### 3. Priority restock — high revenue AND low stock (CTE)

Using two **Common Table Expressions (CTEs)**, the analysis identifies products that are both high-revenue generators *and* critically low in stock — these are the most important items to reorder first.

---

### 4. Who are our most profitable customers?

Customer profit is calculated as:

> `profit = SUM(quantityOrdered × (priceEach − buyPrice))`

**Top 10 VIP customers by profit:**

| Rank | Customer | City | Country | Profit |
|---|---|---|---|---|
| 1 | Euro+ Shopping Channel | Madrid | Spain | $326,519.66 |
| 2 | Mini Gifts Distributors Ltd. | San Rafael | USA | $236,769.39 |
| 3 | Muscle Machine Inc | NYC | USA | $72,370.09 |
| 4 | Australian Collectors, Co. | Melbourne | Australia | $70,311.07 |
| 5 | La Rochelle Gifts | Nantes | France | $60,875.30 |
| 6 | Dragon Souveniers, Ltd. | Singapore | Singapore | $60,477.38 |
| 7 | AV Stores, Co. | Manchester | UK | $60,095.86 |
| 8 | Down Under Souveniers, Inc | Auckland | New Zealand | $60,013.99 |
| 9 | Land of Toys Inc. | NYC | USA | $58,669.10 |
| 10 | The Sharp Gifts Warehouse | San Jose | USA | $55,931.37 |

> **Recommendation:** Target these customers for a dedicated VIP marketing campaign.

---

## SQL Skills Demonstrated

| Technique | Used In |
|---|---|
| `SELECT`, `WHERE`, `GROUP BY`, `ORDER BY` | All sections |
| `JOIN` (inner, multi-table) | Sections 5 – 8 |
| Correlated subqueries | Sections 2 – 3 |
| Common Table Expressions (`WITH … AS`) | Section 4 |
| `UNION ALL` | Section 1 |
| `PRAGMA_TABLE_INFO` | Section 1 |
| `CREATE TEMP TABLE` | Section 5 |
| Aggregate functions (`SUM`, `COUNT`, `ROUND`) | All sections |
| Arithmetic on columns (`priceEach − buyPrice`) | Sections 7 – 8 |
| `LIMIT` | Sections 2, 4, 8 |

---

## Files

```
├── stores.db              # SQLite database (source data)
├── stores_analysis.sql    # Full analysis — clean, commented SQL
└── README.md              # This file
```

---

## How to Run

1. Download `stores.db` and `stores_analysis.sql` into the same folder.
2. Open a SQLite client (e.g. [DB Browser for SQLite](https://sqlitebrowser.org/), DBeaver, or the `sqlite3` CLI).
3. Open `stores.db`.
4. Run the queries in `stores_analysis.sql` section by section.

---

## Tools & Technologies

- **Database:** SQLite 3
- **Language:** SQL (standard SQLite dialect)
- **Client:** DB Browser for SQLite / SQLiteOnline

---

*Project completed as part of the Stanford Online Course on Python & Data Analysis.*
