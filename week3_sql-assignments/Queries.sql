-- Week 3 queries file


--  QUERY 1 — Orders where sales > average sales
-- Meaning : High-Value Orders
--  Concept: SUBQUERY

 
SELECT
    order_id,
    customer_id,
    sales
FROM orders
WHERE sales > (
    SELECT AVG(sales)
    FROM orders
)
ORDER BY sales DESC;
 
 
 

--  QUERY 2 — Highest sales order per customer
-- Meaning- Biggest purchase per customer
--  Concept: CORRELATED SUBQUERY

 
SELECT
    o.customer_id,
    c.customer_name,
    o.order_id,
    o.sales
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.sales = (
    SELECT MAX(o2.sales)
    FROM orders o2
    WHERE o2.customer_id = o.customer_id
)
ORDER BY o.sales DESC;
 

 
 

--  QUERY 3 — Total sales per customer
-- Aggregate spend per customer
--  Concept: CTE

 
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
SELECT *
FROM customer_sales
ORDER BY total_sales DESC;
 
 
 

--  QUERY 4 — Customers with above-average total sales
-- Meaning: Customers spending more than average
--  Concept: CTE + SUBQUERY

 
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
SELECT *
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
 

 
 

--  QUERY 5 — Rank all customers by total sales
-- Meaning: Rank customers by spend
--  Concept: WINDOW FUNCTION — RANK() and DENSE_RANK()

 
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
    customer_id,
    customer_name,
    ROUND(total_sales, 2)                         AS total_sales,
    RANK()       OVER (ORDER BY total_sales DESC) AS sales_rank,
    DENSE_RANK() OVER (ORDER BY total_sales DESC) AS dense_rank
FROM customer_sales;
 

 
 

--  QUERY 6 — Row number per order within each customer
--  Meaning : Sequence order per customers
--  Concept: ROW_NUMBER() + PARTITION BY

 
SELECT
    o.customer_id,
    c.customer_name,
    o.order_id,
    o.order_date,
    o.sales,
    ROW_NUMBER() OVER (
        PARTITION BY o.customer_id
        ORDER BY o.order_date
    ) AS order_sequence
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
ORDER BY o.customer_id, order_sequence;
 
-- ✅ Expected: 9994 rows
-- order_sequence restarts from 1 for every new customer
 
 

--  QUERY 7 — Top 3 customers by total sales
--  Three highest spenders
--  Concept: WINDOW FUNCTION — DENSE_RANK()

 
WITH customer_sales AS (
    SELECT
        o.customer_id,
        c.customer_name,
        SUM(o.sales) AS total_sales
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    GROUP BY o.customer_id, c.customer_name
),
ranked AS (
    SELECT *,
        DENSE_RANK() OVER (ORDER BY total_sales DESC) AS rnk
    FROM customer_sales
)
SELECT
    customer_id,
    customer_name,
    ROUND(total_sales, 2) AS total_sales,
    rnk
FROM ranked
WHERE rnk <= 3;
 