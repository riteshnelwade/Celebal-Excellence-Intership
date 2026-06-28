--  FINAL COMBINED QUERY + Mini Project
-
 
WITH customer_sales AS (
    SELECT
        o.customer_id,
        c.customer_name,
        SUM(o.sales) AS total_sales
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    GROUP BY o.customer_id, c.customer_name
)
SELECT
    customer_name,
    ROUND(total_sales, 2)                   AS total_sales,
    RANK() OVER (ORDER BY total_sales DESC) AS sales_rank
FROM customer_sales
ORDER BY sales_rank;
 

 
 

--  MINI PROJECT — CUSTOMER SALES INSIGHTS
-- ----------------------------------------------------------



--  1 — Top 5 Customers

 
WITH customer_sales AS (
    SELECT
        o.customer_id,
        c.customer_name,
        SUM(o.sales) AS total_sales
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    GROUP BY o.customer_id, c.customer_name
)
SELECT
    customer_name,
    ROUND(total_sales, 2) AS total_sales
FROM customer_sales
ORDER BY total_sales DESC
LIMIT 5;
 

--  2 — Bottom 5 Customers

 
WITH customer_sales AS (
    SELECT
        o.customer_id,
        c.customer_name,
        SUM(o.sales) AS total_sales
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    GROUP BY o.customer_id, c.customer_name
)
SELECT
    customer_name,
    ROUND(total_sales, 2) AS total_sales
FROM customer_sales
ORDER BY total_sales ASC
LIMIT 5;
 

--  3 — Customers who made only ONE order

 
SELECT
    c.customer_id,
    c.customer_name,
    COUNT(DISTINCT o.order_id) AS num_orders
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name
HAVING COUNT(DISTINCT o.order_id) = 1
ORDER BY c.customer_name;
 

--  4 — Customers with above-average sales

 
WITH customer_sales AS (
    SELECT
        o.customer_id,
        c.customer_name,
        SUM(o.sales) AS total_sales
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    GROUP BY o.customer_id, c.customer_name
)
SELECT
    customer_name,
    ROUND(total_sales, 2) AS total_sales
FROM customer_sales
WHERE total_sales > (
    SELECT AVG(total_sales)
    FROM (
        SELECT SUM(sales) AS total_sales
        FROM orders
        GROUP BY customer_id
    ) AS sub
)
ORDER BY total_sales DESC;
 
--  5 — Highest order value per customer

WITH ranked_orders AS (
    SELECT
        o.customer_id,
        c.customer_name,
        o.order_id,
        ROUND(o.sales, 2) AS sales,
        RANK() OVER (
            PARTITION BY o.customer_id
            ORDER BY o.sales DESC
        ) AS rnk
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
)
SELECT
    customer_id,
    customer_name,
    order_id,
    sales AS highest_order_sales
FROM ranked_orders
WHERE rnk = 1
ORDER BY highest_order_sales DESC;
 

 
--  ALL DONE --
