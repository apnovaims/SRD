-- ============================================================================================
-- VIEW: vw_invoice_header_totals
-- --------------------------------------------------------------------------------------------
-- Purpose:
--   Provides a complete invoice header summary for every purchase, including:
--     - Invoice metadata (number and issue date)
--     - Customer billing information (name, address, city/state/country, ZIP code)
--     - Company information (seller office details, email, website)
--     - Financial breakdown (subtotal, discount, tax rate, tax amount, total after tax)
--
-- Logic:
--   - Subtotal     = SUM(Base_Price × Quantity)  SUM aggregates the base amounts across all items in the invoice.
--   - Discount     = Subtotal – SUM(Unit_Price × Quantity)  The difference between the base price and the actual paid price.
--   - Tax          = SUM(Unit_Price × Quantity) × Tax_Rate  VAT is applied to the actual paid amount.
--   - Total        = SUM(Unit_Price × Quantity) + Tax
--
-- Notes:
--   - Subtotal and Discount are calculated per invoice across all purchased items.
--   - Tax is applied after discount, per standard VAT calculation.
--   - City, state, and country fields are concatenated for readability. Our current customers live in countries that do not have states.
-- ============================================================================================

USE polyglotica_ai;

CREATE OR REPLACE VIEW vw_invoice_header_totals AS
SELECT
    -- Invoice
    p.ID_Purchase                               AS Invoice_Number,
    p.Purchase_Datetime                         AS Date_of_Issue,
    -- Customer (billed to)
    CONCAT(cu.First_Name, ' ', cu.Last_Name)                       	AS `Customer Name`,
    cu.Street_Address                           					AS `Customer Street address`,
    CONCAT(cust_city.City_Name, ', ', cust_country.Country_Name) 	AS `Customer City, State, Country`,
    cu.ZipCode                                  					AS `Customer ZIP Code`,
    -- Company (seller)
    co.Company_Name                             					AS `Company name`,
    co.Street_Address                           					AS `Company street`,
    CONCAT(comp_city.City_Name, ', ', comp_country.Country_Name)	AS `Company City, State, Country`,
    co.ZipCode                                  					AS `Company ZIP Code`,
    co.Email                                    					AS `Company email`,
    co.Website                                  					AS `Company website`,
    -- Monetary values
    CONCAT('$', ROUND(SUM(pi.Quantity * pm.Base_Price), 2))                                     AS Subtotal,
    CONCAT('$', ROUND(SUM(pi.Quantity * pm.Base_Price) - SUM(pi.Quantity * pi.Unit_Price), 2))	AS Discount,
    CONCAT(tr.Tax_Percent, '%')                 												AS Tax_Rate,
    CONCAT('$', ROUND(SUM(pi.Quantity * pi.Unit_Price) * tr.Tax_Percent / 100, 2))              AS Tax,
    CONCAT('$', ROUND(SUM(pi.Quantity * pi.Unit_Price) * (1 + tr.Tax_Percent / 100), 2))        AS Total
FROM purchase p
JOIN customer cu
      ON cu.ID_Customer = p.ID_Customer
JOIN city cust_city
      ON cust_city.ID_City = cu.ID_City
JOIN country cust_country
      ON cust_country.ID_Country = cust_city.ID_Country
JOIN company co
      ON co.ID_Company = p.ID_Company
JOIN city comp_city
      ON comp_city.ID_City = co.ID_City
JOIN country comp_country
      ON comp_country.ID_Country = comp_city.ID_Country
JOIN tax_rate tr
      ON tr.ID_Tax = p.ID_Tax
JOIN purchase_item pi
      ON pi.ID_Purchase = p.ID_Purchase
JOIN product_module pm
      ON pm.ID_Product = pi.ID_Product
GROUP BY
    p.ID_Purchase,
    p.Purchase_Datetime,
    cu.First_Name,
    cu.Last_Name,
    cu.Street_Address,
    cu.ZipCode,
    cust_city.City_Name,
    cust_country.Country_Name,
    co.Company_Name,
    co.Street_Address,
    co.ZipCode,
    comp_city.City_Name,
    comp_country.Country_Name,
    co.Email,
    co.Website,
    tr.Tax_Percent;


-- ============================================================================================
-- VIEW: vw_invoice_details
-- --------------------------------------------------------------------------------------------
-- Provides item-level invoice details, including product name, unit cost,
-- quantity, and the pre-discount amount for each purchase.
-- ============================================================================================

USE polyglotica_ai;

CREATE OR REPLACE VIEW vw_invoice_details AS
SELECT
    p.ID_Purchase                                   	AS `Invoice Number`,
    pm.Product_Name                                 	AS `Item Name`,
    CONCAT('$', ROUND(pm.Base_Price, 2))            	AS `Unit Cost`,
    pi.Quantity                                     	AS `Qty`,
    CONCAT('$', ROUND(pi.Quantity * pm.Base_Price, 2))  AS `Amount (Before Discount)`
FROM purchase_item pi
JOIN purchase p
      ON p.ID_Purchase = pi.ID_Purchase
JOIN product_module pm
      ON pm.ID_Product = pi.ID_Product
ORDER BY
    p.ID_Purchase,
    pm.Product_Name;


-- Trigger: Reduce stock when a product is sold
USE polyglotica_ai;

DELIMITER $$

CREATE TRIGGER trg_purchase_item_reduce_stock
AFTER INSERT ON purchase_item
FOR EACH ROW
BEGIN
    UPDATE product_module
    SET Stock_Qty = Stock_Qty - NEW.Quantity
    WHERE ID_Product = NEW.ID_Product;
END$$

DELIMITER ;


-- Trigger: INSERT trigger (on purchase_item) → logs new rows
USE polyglotica_ai;

DELIMITER $$

CREATE TRIGGER trg_pi_log_insert
AFTER INSERT ON purchase_item
FOR EACH ROW
BEGIN
    INSERT INTO log_event (
        Event_Datetime,
        DB_User,
        Table_Name,
        Operation_Type,
        Entity_ID,
        Description
    )
    VALUES (
        NOW(),
        USER(),
        'purchase_item',
        'INSERT',
        NEW.ID_PurchaseItem,
        CONCAT('Inserted new purchase_item: Product ', NEW.ID_Product, ', Qty ', NEW.Quantity)
    );
END$$

DELIMITER ;


-- TEST for both triggers
INSERT INTO purchase_item (ID_Purchase, ID_Product, Quantity, Unit_Price)
VALUES (20, 4, 1, 45.00);

INSERT INTO purchase_item (ID_Purchase, ID_Product, Quantity, Unit_Price)
VALUES (20, 4, 5, 45.00);



-- Query #1.	Top 5 customers by historical purchases 
-- Benefit: Identifies high-value learners.
USE polyglotica_ai;
SELECT 
    cu.ID_Customer,
    CONCAT(cu.First_Name, ' ', cu.Last_Name) AS Customer_Name,
    ROUND(SUM(pi.Quantity * pi.Unit_Price), 2) AS Total_Purchases
FROM purchase_item pi
JOIN purchase p
    ON p.ID_Purchase = pi.ID_Purchase
JOIN customer cu
    ON cu.ID_Customer = p.ID_Customer
GROUP BY cu.ID_Customer, cu.First_Name, cu.Last_Name
ORDER BY Total_Purchases DESC
LIMIT 5;


-- Query #2. 	Annual Sales by Year and City 
-- Benefit: Evaluates geographic performance over time.
-- Limitation: Although it provides correct yearly totals, it is difficult to visually compare cities 
-- across years or identify trends because each year appears as a separate row.
USE polyglotica_ai;
SELECT
    YEAR(p.Purchase_Datetime) AS Year,
    ci.City_Name,
    ROUND(SUM(pi.Quantity * pi.Unit_Price), 2) AS Sales_Amount
FROM purchase_item pi
JOIN purchase p
      ON p.ID_Purchase = pi.ID_Purchase
JOIN customer cu
      ON cu.ID_Customer = p.ID_Customer
LEFT JOIN city ci
      ON ci.ID_City = cu.ID_City
GROUP BY
    YEAR(p.Purchase_Datetime),
    ci.City_Name
ORDER BY
    Year,
    Sales_Amount DESC;


-- Query #3.	Annual Sales Pivot by City (2023–2025)
-- Benefit: Presenting each year as a separate column makes cross-year comparisons much easier and provides 
-- a clearer view of how each city's performance evolves over time. 
USE polyglotica_ai;
WITH sales AS (
    SELECT
        ci.City_Name,
        ROUND(SUM(CASE WHEN YEAR(p.Purchase_Datetime) = 2023 THEN pi.Quantity * pi.Unit_Price ELSE 0 END), 2) AS Sales_2023,
        ROUND(SUM(CASE WHEN YEAR(p.Purchase_Datetime) = 2024 THEN pi.Quantity * pi.Unit_Price ELSE 0 END), 2) AS Sales_2024,
        ROUND(SUM(CASE WHEN YEAR(p.Purchase_Datetime) = 2025 THEN pi.Quantity * pi.Unit_Price ELSE 0 END), 2) AS Sales_2025
    FROM purchase_item pi
    JOIN purchase p  ON p.ID_Purchase = pi.ID_Purchase
    JOIN customer cu ON cu.ID_Customer = p.ID_Customer
    LEFT JOIN city ci ON ci.ID_City = cu.ID_City
    GROUP BY ci.City_Name
)
SELECT
    City_Name,
    Sales_2023,
    Sales_2024,
    Sales_2025,
    Sales_2023 + Sales_2024 + Sales_2025 AS Total
FROM sales
UNION ALL
SELECT
    'TOTAL' AS City_Name,
    SUM(Sales_2023),
    SUM(Sales_2024),
    SUM(Sales_2025),
    SUM(Sales_2023 + Sales_2024 + Sales_2025)
FROM sales
ORDER BY Total DESC;


-- Query #4.	Year-over-Year Sales Δ by City
-- Benefit: Showing the differences between consecutive years highlights real performance changes 
-- and allows quick identification of growth or decline without manual calculations.
USE polyglotica_ai;
WITH sales AS (
    SELECT
        ci.City_Name,
        ROUND(SUM(CASE WHEN YEAR(p.Purchase_Datetime) = 2023 THEN pi.Quantity * pi.Unit_Price ELSE 0 END), 2) AS Sales_2023,
        ROUND(SUM(CASE WHEN YEAR(p.Purchase_Datetime) = 2024 THEN pi.Quantity * pi.Unit_Price ELSE 0 END), 2) AS Sales_2024,
        ROUND(SUM(CASE WHEN YEAR(p.Purchase_Datetime) = 2025 THEN pi.Quantity * pi.Unit_Price ELSE 0 END), 2) AS Sales_2025
    FROM purchase_item pi
    JOIN purchase p   ON p.ID_Purchase = pi.ID_Purchase
    JOIN customer cu  ON cu.ID_Customer = p.ID_Customer
    LEFT JOIN city ci ON ci.ID_City = cu.ID_City
    GROUP BY ci.City_Name
)
SELECT
    City_Name,
    (Sales_2024 - Sales_2023) AS Delta_2024_vs_2023,
    (Sales_2025 - Sales_2024) AS Delta_2025_vs_2024,
    (Sales_2024 - Sales_2023) + (Sales_2025 - Sales_2024) AS Total_Delta
FROM sales
ORDER BY
    Total_Delta DESC;

-- Query #5.	Customer Product-Group Sales Summary (with Totals)
-- Benefit: Provides an alternative view of sales distribution while preserving overall totals.
USE polyglotica_ai;
WITH customer_sales AS (
SELECT
    cu.ID_Customer,
    CONCAT(cu.First_Name, ' ', cu.Last_Name) AS Customer,
    -- Product Group 1: Beginner (Portuguese, Spanish, French)
    ROUND(SUM(CASE WHEN pm.Product_Name LIKE '%Beginner' THEN pi.Quantity * pi.Unit_Price ELSE 0 END), 2) AS `Beginner`,
    -- Product Group 2: Intermediate (Portuguese, Spanish, French)
    ROUND(SUM(CASE WHEN pm.Product_Name LIKE '%Intermediate' AND pm.Product_Name NOT LIKE '%Upper%' THEN pi.Quantity * pi.Unit_Price ELSE 0 END), 2) AS `Intermediate`,
    -- Product Group 3: Upper Intermediate (Portuguese, Spanish, French)
    ROUND(SUM(CASE WHEN pm.Product_Name LIKE '%Upper Intermediate' THEN pi.Quantity * pi.Unit_Price ELSE 0 END), 2) AS `Upper Intermediate`,
    -- Product Group 4: Advanced (Portuguese, Spanish, French)
    ROUND(SUM(CASE WHEN pm.Product_Name LIKE '%Advanced' THEN pi.Quantity * pi.Unit_Price ELSE 0 END), 2) AS `Advanced`,
    -- Product Group 5: Professional (Portuguese, Spanish, French)
    ROUND(SUM(CASE WHEN pm.Product_Name LIKE '%Professional' THEN pi.Quantity * pi.Unit_Price ELSE 0 END), 2) AS `Professional`,
    -- Product Group 6: Word Cards (Portuguese, Spanish, French)
    ROUND(SUM(CASE WHEN pm.Product_Name LIKE '%Word Cards' THEN pi.Quantity * pi.Unit_Price ELSE 0 END), 2) AS `Word Cards`,
    -- Product Group 7: Crosswords (Portuguese, Spanish, French)
    ROUND(SUM(CASE WHEN pm.Product_Name LIKE '%Crosswords' THEN pi.Quantity * pi.Unit_Price ELSE 0 END), 2) AS `Crosswords`,
    -- Total for all products
    ROUND(SUM(COALESCE(pi.Quantity * pi.Unit_Price, 0)), 2) AS Total
FROM purchase_item pi
JOIN purchase p
    ON p.ID_Purchase = pi.ID_Purchase
JOIN customer cu
    ON cu.ID_Customer = p.ID_Customer
JOIN product_module pm
    ON pm.ID_Product = pi.ID_Product
GROUP BY
    cu.ID_Customer,
    cu.First_Name,
    cu.Last_Name
HAVING Total > 0
ORDER BY
    Total DESC
)
SELECT *
FROM customer_sales
UNION ALL
SELECT
    'Total' AS ID_Customer,
    ' '     AS Customer,
    ROUND(SUM(Beginner), 2)             AS Beginner,
    ROUND(SUM(Intermediate), 2)         AS Intermediate,
    ROUND(SUM(`Upper Intermediate`), 2) AS `Upper Intermediate`,
    ROUND(SUM(Advanced), 2)             AS Advanced,
    ROUND(SUM(Professional), 2)         AS Professional,
    ROUND(SUM(`Word Cards`), 2)         AS `Word Cards`,
    ROUND(SUM(Crosswords), 2)           AS Crosswords,
    ROUND(SUM(Total), 2)                AS Total
FROM customer_sales
ORDER BY
    Total DESC;

-- Query #6.	Top-rated products by Gender and Age 
-- Benefit: Highlights which modules are preferred by specific demographic groups. 
USE polyglotica_ai;
SELECT
    cu.Gender,
    CASE
        WHEN TIMESTAMPDIFF(YEAR, cu.Birthdate, CURDATE()) < 25 THEN 'Under 25'
        WHEN TIMESTAMPDIFF(YEAR, cu.Birthdate, CURDATE()) BETWEEN 25 AND 34 THEN '25–34'
        WHEN TIMESTAMPDIFF(YEAR, cu.Birthdate, CURDATE()) BETWEEN 35 AND 44 THEN '35–44'
        ELSE '45+'
    END AS Age_Group,
    pm.Product_Name,
    ROUND(AVG(r.Rating_Value), 2) AS Avg_Rating,
    COUNT(*) AS Num_Ratings
FROM rating r
JOIN customer cu
    ON cu.ID_Customer = r.ID_Customer
JOIN product_module pm
    ON pm.ID_Product = r.ID_Product
GROUP BY
    cu.Gender,
    Age_Group,
    pm.Product_Name
ORDER BY
    cu.Gender,
    Age_Group,
    Avg_Rating DESC,
    Num_Ratings DESC;