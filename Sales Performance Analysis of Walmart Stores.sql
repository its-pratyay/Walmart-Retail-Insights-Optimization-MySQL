-- $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
--  Sales Performance Analysis of Walmart Stores Using Advanced MySQL Techniques
-- $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

CREATE TABLE walmart_sales (
    invoice_id VARCHAR(30),
    branch VARCHAR(10),
    city VARCHAR(50),
    customer_type VARCHAR(20),
    gender VARCHAR(10),
    product_line VARCHAR(100),
    unit_price DECIMAL(10,2),
    quantity INT,
    tax DECIMAL(10,2),
    total DECIMAL(10,2),
    date DATE,
    time TIME,
    payment VARCHAR(20),
    cogs DECIMAL(10,2),
    gross_margin_percentage DECIMAL(10,2),
    gross_income DECIMAL(10,2),
    rating FLOAT,
    customer_id INT
);
SELECT*FROM walmart_sales;
-- Task 1: Identifying the Top Branch by Sales Growth Rate
-- Step 1: Calculate total monthly sales for each branch
WITH MonthlySales AS (
    SELECT 
        branch,
        DATE_FORMAT(date, '%Y-%m') AS month,  -- Format the date as Year-Month (e.g., 2025-06)
        SUM(total) AS sales                   -- Total sales in that month
    FROM walmart_sales
    GROUP BY branch, month                   -- Group by branch and month
),

-- Step 2: Calculate month-over-month sales using LAG() function
GrowthCalc AS (
    SELECT 
        branch,
        month,
        sales,
        LAG(sales) OVER (PARTITION BY branch ORDER BY month) AS prev_month_sales
        -- LAG() gives previous month's sales for the same branch
    FROM MonthlySales
),

-- Step 3: Calculate growth rate and remove rows where previous month data is not available
GrowthRates AS (
    SELECT 
        branch,
        month,
        sales,
        prev_month_sales,
        ROUND(((sales - prev_month_sales) / prev_month_sales) * 100, 2) AS growth_rate
        -- Formula: ((current - previous) / previous) * 100 for growth %
    FROM GrowthCalc
    WHERE prev_month_sales IS NOT NULL  -- Exclude first month (no previous sales to compare)
)

-- Step 4: Get the top growing branch-month combination
SELECT 
    branch,
    month,
    growth_rate
FROM GrowthRates
ORDER BY growth_rate DESC
LIMIT 10;  -- Only the top growth result

-- Task 2: Finding the Most Profitable Product Line for Each Branch
-- Step 1: Calculate total profit for each product line in each branch
SELECT 
    branch,
    product_line,
    SUM(gross_income) AS total_profit  -- gross_income = profit
FROM walmart_sales
GROUP BY branch, product_line;

-- Step 2: Find the most profitable product line per branch
WITH ProfitPerLine AS (
    SELECT 
        branch,
        product_line,
        SUM(gross_income) AS total_profit
    FROM walmart_sales
    GROUP BY branch, product_line
),
RankedProfit AS (
    SELECT 
        branch,
        product_line,
        total_profit,
        RANK() OVER (PARTITION BY branch ORDER BY total_profit DESC) AS profit_rank
    FROM ProfitPerLine
)
-- Step 3: Select only the top product line per branch
SELECT 
    branch,
    product_line AS most_profitable_product_line,
    total_profit
FROM RankedProfit
WHERE profit_rank = 1;

-- Task 3: Analyzing Customer Segmentation Based on Spending
-- Step 1: Calculate total spending by each customer
WITH CustomerSpending AS (
    SELECT 
        customer_id,
        SUM(total) AS total_spent
    FROM walmart_sales
    GROUP BY customer_id
),

-- Step 2: Define tiers using quantiles (33% = Low, 33–66% = Medium, >66% = High)
RankedSpending AS (
    SELECT 
        customer_id,
        total_spent,
        NTILE(3) OVER (ORDER BY total_spent DESC) AS spending_tier
        -- NTILE(3) breaks the list into 3 equal groups: 1=High, 2=Medium, 3=Low
    FROM CustomerSpending
)

-- Step 3: Assign readable labels to each tier
SELECT 
    customer_id,
    total_spent,
    CASE 
        WHEN spending_tier = 1 THEN 'High'
        WHEN spending_tier = 2 THEN 'Medium'
        WHEN spending_tier = 3 THEN 'Low'
    END AS spending_category
FROM RankedSpending;

-- Task 4: Detecting Anomalies in Sales Transactions
-- Step 1: Calculate average and standard deviation of total sales for each product line
WITH ProductStats AS (
    SELECT 
        product_line,
        AVG(total) AS avg_total,
        STDDEV(total) AS std_total
    FROM walmart_sales
    GROUP BY product_line
),

-- Step 2: Join with original table and calculate z-score
TransactionZScores AS (
    SELECT 
        ws.invoice_id,
        ws.product_line,
        ws.total,
        ps.avg_total,
        ps.std_total,
        -- Z-score formula
        (ws.total - ps.avg_total) / ps.std_total AS z_score
    FROM walmart_sales ws
    JOIN ProductStats ps
    ON ws.product_line = ps.product_line
)

-- Step 3: Filter anomalies (Z-score > 2 or < -2)
SELECT 
    invoice_id,
    product_line,
    total,
    ROUND(z_score, 2) AS z_score
FROM TransactionZScores
WHERE ABS(z_score) > 2
ORDER BY z_score DESC;

-- Task 5: Most Popular Payment Method by City 
-- Step 1: Count payment method usage by city
WITH PaymentCounts AS (
    SELECT 
        city,
        payment,
        COUNT(*) AS payment_count
    FROM walmart_sales
    GROUP BY city, payment
),

-- Step 2: Rank payment methods within each city
RankedPayments AS (
    SELECT 
        city,
        payment,
        payment_count,
        RANK() OVER (PARTITION BY city ORDER BY payment_count DESC) AS payment_rank
    FROM PaymentCounts
)

-- Step 3: Get only the top payment method per city
SELECT 
    city,
    payment AS most_popular_payment,
    payment_count
FROM RankedPayments
WHERE payment_rank = 1;

-- Task 6: Monthly Sales Distribution by Gender
-- Step 1: Extract the month from the date and group by gender
SELECT 
    DATE_FORMAT(date, '%Y-%m') AS sales_month,  -- Formats date as 'YYYY-MM'
    gender,
    ROUND(SUM(total), 2) AS total_sales
FROM walmart_sales
GROUP BY sales_month, gender
ORDER BY sales_month, gender;

-- Task 7: Best Product Line by Customer Type
-- Step 1: Count total sales by product line and customer type
WITH ProductPreference AS (
    SELECT 
        customer_type,
        product_line,
        SUM(quantity) AS total_units_sold
    FROM walmart_sales
    GROUP BY customer_type, product_line
),

-- Step 2: Rank product lines for each customer type
RankedPreferences AS (
    SELECT 
        customer_type,
        product_line,
        total_units_sold,
        RANK() OVER (PARTITION BY customer_type ORDER BY total_units_sold DESC) AS _rank
    FROM ProductPreference
)

-- Step 3: Select top product line for each customer type
SELECT 
    customer_type,
    product_line AS best_product_line,
    total_units_sold
FROM RankedPreferences
WHERE _rank = 1;

-- Task 8: Identifying Repeat Customers
-- Step 1: Self-join to find purchase pairs within 30 days
SELECT 
    a.customer_id,
    a.date AS first_purchase,
    b.date AS repeat_purchase,
    DATEDIFF(b.date, a.date) AS days_between
FROM walmart_sales a
JOIN walmart_sales b
    ON a.customer_id = b.customer_id
   AND b.date > a.date
   AND DATEDIFF(b.date, a.date) <= 30
GROUP BY a.customer_id, a.date, b.date
ORDER BY a.customer_id, a.date;

-- Task 9: Finding Top 5 Customers by Sales Volume
-- Step 1: Calculate total revenue per customer
SELECT 
    customer_id,
    ROUND(SUM(total), 2) AS total_revenue
FROM walmart_sales
GROUP BY customer_id
ORDER BY total_revenue DESC
LIMIT 5;  -- Only top 5 customers

-- Task 10: Analyzing Sales Trends by Day of the Week
-- Step 1: Add weekday column using DAYNAME()
SELECT 
    DAYNAME(date) AS day_of_week,
    ROUND(SUM(total), 2) AS total_sales
FROM walmart_sales
GROUP BY day_of_week
ORDER BY total_sales DESC;







