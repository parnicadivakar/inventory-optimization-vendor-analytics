CREATE DATABASE retail_inventory_analytics;
CREATE SCHEMA retail;
CREATE TABLE retail.beginning_inventory (
    inventory_id VARCHAR(100),
    store INT,
    city VARCHAR(100),
    brand INT,
    description VARCHAR(255),
    size VARCHAR(50),
    on_hand INT,
    price NUMERIC(10,2),
    start_date DATE
);

CREATE TABLE retail.ending_inventory (
    inventory_id VARCHAR(100),
    store INT,
    city VARCHAR(100),
    brand INT,
    description VARCHAR(255),
    size VARCHAR(50),
    on_hand INT,
    price NUMERIC(10,2),
    end_date DATE
);

CREATE TABLE retail.purchase_prices (
    brand INT,
    description VARCHAR(255),
    price NUMERIC(10,2),
    size VARCHAR(50),
   volume VARCHAR(50),
    classification INT,
    purchase_price NUMERIC(10,2),
    vendor_number INT,
    vendor_name VARCHAR(255)
);

CREATE TABLE retail.purchases (
    inventory_id VARCHAR(100),
    store INT,
    brand INT,
    description VARCHAR(255),
    size VARCHAR(50),
    vendor_number INT,
    vendor_name VARCHAR(255),
    po_number INT,
    po_date DATE,
    receiving_date DATE,
    invoice_date DATE,
    pay_date DATE,
    purchase_price NUMERIC(10,2),
    quantity INT,
    dollars NUMERIC(12,2),
    classification INT
);

CREATE TABLE retail.vendor_invoices (
    vendor_number INT,
    vendor_name VARCHAR(255),
    invoice_date DATE,
    po_number INT,
    po_date DATE,
    pay_date DATE,
    quantity INT,
    dollars NUMERIC(12,2),
    freight NUMERIC(12,2),
    approval VARCHAR(50)
);

CREATE TABLE retail.sales (
    inventory_id VARCHAR(100),
    store INT,
    brand INT,
    description VARCHAR(255),
    size VARCHAR(50),
    sales_quantity INT,
    sales_dollars NUMERIC(12,2),
    sales_price NUMERIC(10,2),
    sales_date DATE,
    volume INT,
    classification INT,
    excise_tax NUMERIC(10,2),
    vendor_number INT,
    vendor_name VARCHAR(255)
);

SELECT table_name
FROM information_schema.tables
WHERE table_schema='retail';

SELECT 'beginning_inventory', COUNT(*)
FROM retail.beginning_inventory
UNION ALL

SELECT 'ending_inventory', COUNT(*)
FROM retail.ending_inventory
UNION ALL

SELECT 'purchase_prices', COUNT(*)
FROM retail.purchase_prices
UNION ALL

SELECT 'vendor_invoices', COUNT(*)
FROM retail.vendor_invoices
UNION ALL

SELECT 'purchases', COUNT(*)
FROM retail.purchases
UNION ALL

SELECT 'sales', COUNT(*)
FROM retail.sales;

--KPI query

SELECT
    ROUND(SUM(sales_dollars),2) AS total_revenue,
    SUM(sales_quantity) AS total_units_sold,
    COUNT(DISTINCT brand) AS total_products,
    COUNT(DISTINCT vendor_number) AS total_vendors,
    COUNT(DISTINCT store) AS total_stores
FROM retail.sales;

--Which months performed best
--Revenue trend over time
--Whether sales are growing or declining

SELECT
    DATE_TRUNC('month', sales_date)::date AS month,
    ROUND(SUM(sales_dollars),2) AS revenue
FROM retail.sales
GROUP BY 1
ORDER BY 1;

--Which vendors generate the most revenue?
SELECT
    vendor_name,
    ROUND(SUM(sales_dollars),2) AS revenue
FROM retail.sales
GROUP BY vendor_name
ORDER BY revenue DESC
LIMIT 10;

--Which products generate the highest revenue?
SELECT
    description,
    ROUND(SUM(sales_dollars),2) AS revenue
FROM retail.sales
GROUP BY description
ORDER BY revenue DESC
LIMIT 10;

--Which products generate the most profit?
SELECT
    s.brand,
    s.description,
    ROUND(SUM(s.sales_dollars),2) AS revenue,
    ROUND(
        SUM(s.sales_quantity * pp.purchase_price),
        2
    ) AS cost,
    ROUND(
        SUM(s.sales_dollars) -
        SUM(s.sales_quantity * pp.purchase_price),
        2
    ) AS profit
FROM retail.sales s
JOIN retail.purchase_prices pp
ON s.brand = pp.brand
GROUP BY s.brand,s.description
ORDER BY profit DESC
LIMIT 20;

--How dependent is the company on each vendor?
SELECT
    vendor_name,
    ROUND(
        100 * SUM(sales_dollars)
        /
        SUM(SUM(sales_dollars)) OVER(),
        2
    ) AS contribution_pct
FROM retail.sales
GROUP BY vendor_name
ORDER BY contribution_pct DESC;

--Which products move quickly and which products sit in inventory?
SELECT
    s.brand,
    s.description,
    SUM(s.sales_quantity) AS units_sold,
    AVG(e.on_hand) AS avg_inventory,
    ROUND(
        SUM(s.sales_quantity)::numeric /
        NULLIF(AVG(e.on_hand),0),
        2
    ) AS turnover_ratio
FROM retail.sales s
JOIN retail.ending_inventory e
ON s.brand = e.brand
GROUP BY s.brand,s.description
ORDER BY turnover_ratio DESC
LIMIT 20;

WITH product_revenue AS
(
    SELECT
        description,
        SUM(sales_dollars) AS revenue
    FROM retail.sales
    GROUP BY description
),

ranked_products AS
(
    SELECT
        description,
        revenue,
        SUM(revenue) OVER (
            ORDER BY revenue DESC
        ) AS cumulative_revenue,
        SUM(revenue) OVER () AS total_revenue
    FROM product_revenue
)

SELECT
    description,
    revenue,
    ROUND(
        cumulative_revenue * 100.0 / total_revenue,
        2
    ) AS cumulative_pct,
    CASE
        WHEN cumulative_revenue * 100.0 / total_revenue <= 80 THEN 'A'
        WHEN cumulative_revenue * 100.0 / total_revenue <= 95 THEN 'B'
        ELSE 'C'
    END AS abc_category
FROM ranked_products
ORDER BY revenue DESC;

--Which products are sitting in inventory but not selling?
SELECT
    e.brand,
    e.description,
    e.on_hand AS current_stock,
    COALESCE(SUM(s.sales_quantity),0) AS units_sold
FROM retail.ending_inventory e
LEFT JOIN retail.sales s
ON e.brand = s.brand
GROUP BY
    e.brand,
    e.description,
    e.on_hand
HAVING COALESCE(SUM(s.sales_quantity),0) = 0
ORDER BY current_stock DESC;

--Which stores generate the most revenue?
SELECT
    store,
    ROUND(SUM(sales_dollars),2) AS revenue,
    SUM(sales_quantity) AS units_sold
FROM retail.sales
GROUP BY store
ORDER BY revenue DESC;

--Which products generate the highest profit margin?
SELECT
    s.brand,
    s.description,
    ROUND(SUM(s.sales_dollars),2) AS revenue,
    ROUND(SUM(s.sales_quantity * pp.purchase_price),2) AS cost,
    ROUND(
        SUM(s.sales_dollars) -
        SUM(s.sales_quantity * pp.purchase_price),
        2
    ) AS profit,
    ROUND(
        (
            (SUM(s.sales_dollars) -
             SUM(s.sales_quantity * pp.purchase_price))
            /
            NULLIF(SUM(s.sales_dollars),0)
        ) * 100,
        2
    ) AS margin_pct
FROM retail.sales s
JOIN retail.purchase_prices pp
ON s.brand = pp.brand
GROUP BY s.brand,s.description
ORDER BY margin_pct DESC
LIMIT 20;










