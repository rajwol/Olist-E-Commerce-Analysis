--Creating a view to filter out canceled & unavailable orders
CREATE VIEW vw_valid_orders AS
SELECT *
FROM orders
WHERE order_status NOT IN ('canceled','unavailable');

--Summary Dashboard KPIs

--Total Revenue
SELECT SUM(payment_value)
FROM vw_valid_orders o 
JOIN order_payments op
	ON o.order_id = op.order_id

--Total Customers
SELECT COUNT(DISTINCT customer_unique_id)
FROM customers

--Total Orders (Fulfilled)
SELECT COUNT(DISTINCT order_id)
FROM vw_valid_orders

--Total Products
SELECT COUNT(DISTINCT product_id)
FROM products

--Revenue & Orders Over Time
SELECT 
    FORMAT(o.order_purchase_timestamp, 'yyyy-MM') AS order_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(p.payment_value) AS total_revenue
FROM 
    vw_valid_orders o
JOIN 
    order_payments p 
    ON o.order_id = p.order_id
GROUP BY 
    FORMAT(o.order_purchase_timestamp, 'yyyy-MM')
ORDER BY 
    order_month;

--Revenue by customer state
SELECT 
	customer_state,
	ROUND(SUM(payment_value), 2) AS state_revenue,
	ROUND(SUM(SUM(payment_value)) OVER (ORDER BY SUM(payment_value) ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS cumulative_revenue,
	ROUND(SUM(payment_value) / SUM(SUM(payment_value)) OVER () *100.0, 2) AS revenue_percent
FROM 
	vw_valid_orders o
JOIN 
	customers c 
	ON o.customer_id = c.customer_id
JOIN 
	order_payments p 
	ON o.order_id = p.order_id
GROUP BY 
	customer_state
ORDER BY 
	state_revenue;

--Revenue by Product Category
SELECT 
    pr.product_category_name,
    SUM(oi.price) AS total_revenue
FROM 
    order_items oi
JOIN 
    products pr 
    ON oi.product_id = pr.product_id
JOIN 
    vw_valid_orders o
    ON oi.order_id = o.order_id
GROUP BY 
    pr.product_category_name
ORDER BY 
    total_revenue DESC;

--Review score Distribution
SELECT 
	review_score, COUNT(review_score)
FROM 
	order_reviews r
JOIN 
	vw_valid_orders o 
	ON r.order_id = o.order_id
GROUP BY 
	review_score
ORDER BY
	review_score

--Customer Type Distribution
WITH orders_per_customer_CTE AS 
	(SELECT c.customer_unique_id, COUNT(order_id) AS orders
	FROM customers c
	JOIN vw_valid_orders o ON c.customer_id = o.customer_id
	GROUP BY c.customer_unique_id)

SELECT 
	SUM(CASE WHEN orders = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS 'one-time customer',
	SUM(CASE WHEN orders > 1 THEN 1  ELSE 0 END) * 100.0 / COUNT(*) AS 'repeat customer'
FROM 
	orders_per_customer_CTE

--Shipping Dashboard

--Freight value
SELECT 
    SUM(oi.freight_value) AS total_freight_value
FROM 
    order_items oi
JOIN 
    vw_valid_orders o 
    ON oi.order_id = o.order_id

--Avg Delivery Times
SELECT 
	AVG(DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date))
FROM 
	vw_valid_orders
WHERE 
	order_purchase_timestamp IS NOT NULL
	AND order_delivered_customer_date IS NOT NULL

-- On-Time/Early & Late Deliveries
SELECT 
    COUNT(CASE 
        WHEN CAST(order_delivered_customer_date AS DATE) <= CAST(order_estimated_delivery_date AS DATE) THEN 1 
        END) * 100.0 / COUNT(*) AS pct_early_or_ontime,
    
    COUNT(CASE 
        WHEN CAST(order_delivered_customer_date AS DATE) > CAST(order_estimated_delivery_date AS DATE) THEN 1 
        END) * 100.0 / COUNT(*) AS pct_late
FROM 
	vw_valid_orders
WHERE 
	order_delivered_customer_date IS NOT NULL
    AND order_estimated_delivery_date IS NOT NULL
	AND order_purchase_timestamp IS NOT NULL;

--Logistics Performance By Seller State
SELECT
	s.seller_state,
	ROUND(AVG(oi.freight_value),2) AS avg_freight_value,
	ROUND(AVG(DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date)),2) AS avg_delivery_days
FROM 
	order_items oi 
JOIN 
	vw_valid_orders o
	ON oi.order_id = o.order_id
JOIN 
	sellers s
	ON oi.seller_id = s.seller_id
WHERE 
	o.order_purchase_timestamp IS NOT NULL
	AND o.order_delivered_customer_date IS NOT NULL
GROUP BY 
	s.seller_state
ORDER BY 
	avg_delivery_days DESC	

-- AVG. Delivery Time by Review Score
SELECT 
	review_score,
	AVG(DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date))
FROM
	order_reviews r
JOIN
	vw_valid_orders o 
	ON r.order_id = o.order_id
GROUP BY 
	review_score
ORDER BY
	review_score

-- Delivery Timeliness 
SELECT 
    FORMAT(order_purchase_timestamp, 'yyyy-MM') AS order_month,
	SUM(CASE WHEN CAST(order_delivered_customer_date AS DATE) <= CAST(order_estimated_delivery_date AS DATE) THEN 1 END) AS 'good deliveries',
	SUM(CASE WHEN CAST(order_delivered_customer_date AS DATE) > CAST(order_estimated_delivery_date AS DATE) THEN 1 END) AS 'late deliveries'
FROM
	orders
GROUP BY
	FORMAT(order_purchase_timestamp, 'yyyy-MM')
ORDER BY
	order_month