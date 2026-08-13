-- ==========================================
-- CREATE DATABASE
-- ==========================================
DROP DATABASE IF EXISTS polyglotica_ai;
CREATE DATABASE polyglotica_ai;
USE polyglotica_ai;

-- ==========================================
-- DROP TABLES IF THEY EXIST (FK-safe order)
-- ==========================================
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS
  log_event,
  payment,
  rating,
  purchase_item,
  purchase,
  tax_rate,
  promotion_product,
  promotion,
  product_module,
  module_level,
  language,
  customer,
  company,
  city,
  country;

SET FOREIGN_KEY_CHECKS = 1;

-- ==========================================
-- TABLES (15 TABLES, ALL 3NF)
-- ==========================================

-- 1. COUNTRY (Portugal only)
CREATE TABLE country (
    ID_Country    INT NOT NULL AUTO_INCREMENT,
    Country_Name  VARCHAR(100) NOT NULL,
    ISO2_Code     CHAR(2) NOT NULL,
    PRIMARY KEY (ID_Country),
    UNIQUE KEY uq_country_iso2 (ISO2_Code)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


-- 2. CITY (Portuguese cities)
CREATE TABLE city (
    ID_City     INT NOT NULL AUTO_INCREMENT,
    ID_Country  INT NOT NULL,
    City_Name   VARCHAR(100) NOT NULL,
    PRIMARY KEY (ID_City),
    KEY fk_city_country_idx (ID_Country),
    CONSTRAINT fk_city_country
        FOREIGN KEY (ID_Country)
        REFERENCES country (ID_Country)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


-- 3. COMPANY (only HQ in Lisboa Centro)
CREATE TABLE company (
    ID_Company INT NOT NULL AUTO_INCREMENT,
    Company_Name VARCHAR(100) NOT NULL,
    Legal_Name VARCHAR(150) NOT NULL,
    Tax_ID VARCHAR(30) NOT NULL,
    Country_Code CHAR(2) NOT NULL,
    ID_City INT NOT NULL,
    Street_Address VARCHAR(200) NOT NULL,
    ZipCode VARCHAR(20) NOT NULL,
    Phone VARCHAR(30),
    Email VARCHAR(100),
    Website VARCHAR(200),

    PRIMARY KEY (ID_Company),

    CONSTRAINT fk_company_country
        FOREIGN KEY (Country_Code)
        REFERENCES country (ISO2_Code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_company_city
        FOREIGN KEY (ID_City)
        REFERENCES city (ID_City)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


-- 4. CUSTOMER (Portuguese buyers with full address)
CREATE TABLE customer (
    ID_Customer            INT NOT NULL AUTO_INCREMENT,
    First_Name             VARCHAR(50) NOT NULL,
    Last_Name              VARCHAR(50) NOT NULL,
    Email                  VARCHAR(150) NOT NULL,
    Gender                 ENUM('F','M','O') DEFAULT NULL,
    Birthdate              DATE DEFAULT NULL,
    Street_Address         VARCHAR(200) DEFAULT NULL,
    ZipCode                VARCHAR(15) DEFAULT NULL,
    ID_City                INT DEFAULT NULL,
    Registration_Datetime  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ID_Customer),
    UNIQUE KEY uq_customer_email (Email),
    KEY fk_customer_city_idx (ID_City),
    CONSTRAINT fk_customer_city
        FOREIGN KEY (ID_City)
        REFERENCES city (ID_City)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


-- 5. LANGUAGE (learning languages)
-- We keep only what matters: PT, ES, FR
CREATE TABLE language (
    ID_Language    INT NOT NULL AUTO_INCREMENT,
    Language_Code  VARCHAR(10) NOT NULL,
    Language_Name  VARCHAR(50) NOT NULL,
    PRIMARY KEY (ID_Language),
    UNIQUE KEY uq_language_code (Language_Code)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


-- 6. MODULE_LEVEL (levels + supplements)
CREATE TABLE module_level (
    ID_Level       INT NOT NULL AUTO_INCREMENT,
    Level_Code     VARCHAR(30) NOT NULL,   -- BEGINNER, WORD_CARDS, etc.
    Level_Name     VARCHAR(100) NOT NULL,
    Is_Core        TINYINT(1) NOT NULL,    -- 1 = core level, 0 = supplement
    Display_Order  INT NOT NULL,
    PRIMARY KEY (ID_Level),
    UNIQUE KEY uq_module_level_code (Level_Code)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


-- 7. PRODUCT_MODULE (Language x Level), with base price
CREATE TABLE product_module (
    ID_Product    INT NOT NULL AUTO_INCREMENT,
    ID_Language   INT NOT NULL,
    ID_Level      INT NOT NULL,
    Product_Name  VARCHAR(150) NOT NULL,
    Base_Price    DECIMAL(8,2) NOT NULL,
    Stock_Qty     INT NOT NULL DEFAULT 0,       -- NEW COLUMN
    Is_Active     TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (ID_Product),
    KEY fk_product_language_idx (ID_Language),
    KEY fk_product_level_idx (ID_Level),
    CONSTRAINT fk_product_language
        FOREIGN KEY (ID_Language)
        REFERENCES language (ID_Language)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_product_level
        FOREIGN KEY (ID_Level)
        REFERENCES module_level (ID_Level)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


-- 8. PROMOTION (event / seasonal)
CREATE TABLE promotion (
    ID_Promotion        INT NOT NULL AUTO_INCREMENT,
    Promotion_Code      VARCHAR(50) NOT NULL,
    Promotion_Name      VARCHAR(150) NOT NULL,
    Promotion_Type      ENUM('EVENT','SEASONAL') NOT NULL,
    Start_Date          DATE NOT NULL,
    End_Date            DATE NOT NULL,
    Discount_Percent    DECIMAL(5,2) NOT NULL,
    Is_Active           TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (ID_Promotion),
    UNIQUE KEY uq_promotion_code (Promotion_Code)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


-- 9. PROMOTION_PRODUCT (eligible products per promotion)
CREATE TABLE promotion_product (
    ID_Promotion  INT NOT NULL,
    ID_Product    INT NOT NULL,
    PRIMARY KEY (ID_Promotion, ID_Product),
    KEY fk_pp_product_idx (ID_Product),
    CONSTRAINT fk_pp_promotion
        FOREIGN KEY (ID_Promotion)
        REFERENCES promotion (ID_Promotion)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_pp_product
        FOREIGN KEY (ID_Product)
        REFERENCES product_module (ID_Product)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


-- 10. TAX_RATE (Portuguese VAT only, but table is generic)
CREATE TABLE tax_rate (
    ID_Tax       INT NOT NULL AUTO_INCREMENT,
    Tax_Name     VARCHAR(100) NOT NULL,    -- 'PT Standard VAT'
    Country_Code CHAR(2) NOT NULL,         -- 'PT'
    Tax_Percent  DECIMAL(5,2) NOT NULL,    -- 23.00
    PRIMARY KEY (ID_Tax)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


-- 11. PURCHASE (order / invoice header)
CREATE TABLE purchase (
    ID_Purchase        INT NOT NULL AUTO_INCREMENT,
    ID_Customer        INT NOT NULL,
    ID_Company         INT NOT NULL,
    ID_Promotion       INT DEFAULT NULL,
    ID_Tax             INT NOT NULL,
    Purchase_Datetime  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ID_Purchase),
    KEY fk_purchase_customer_idx (ID_Customer),
    KEY fk_purchase_company_idx (ID_Company),
    KEY fk_purchase_promotion_idx (ID_Promotion),
    KEY fk_purchase_tax_idx (ID_Tax),
    CONSTRAINT fk_purchase_customer
        FOREIGN KEY (ID_Customer)
        REFERENCES customer (ID_Customer)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_purchase_company
        FOREIGN KEY (ID_Company)
        REFERENCES company (ID_Company)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_purchase_promotion
        FOREIGN KEY (ID_Promotion)
        REFERENCES promotion (ID_Promotion)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_purchase_tax
        FOREIGN KEY (ID_Tax)
        REFERENCES tax_rate (ID_Tax)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


-- 12. PURCHASE_ITEM (order lines)
CREATE TABLE purchase_item (
    ID_PurchaseItem   INT NOT NULL AUTO_INCREMENT,
    ID_Purchase       INT NOT NULL,
    ID_Product        INT NOT NULL,
    Quantity          INT NOT NULL DEFAULT 1,
    Unit_Price        DECIMAL(8,2) NOT NULL,
    PRIMARY KEY (ID_PurchaseItem),
    KEY fk_pi_purchase_idx (ID_Purchase),
    KEY fk_pi_product_idx (ID_Product),
    CONSTRAINT fk_pi_purchase
        FOREIGN KEY (ID_Purchase)
        REFERENCES purchase (ID_Purchase)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_pi_product
        FOREIGN KEY (ID_Product)
        REFERENCES product_module (ID_Product)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


-- 13. RATING (customer product ratings)
CREATE TABLE rating (
    ID_Rating        INT NOT NULL AUTO_INCREMENT,
    ID_Customer      INT NOT NULL,
    ID_Product       INT NOT NULL,
    Rating_Value     TINYINT NOT NULL,
    Rating_Datetime  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Bonus_Granted    TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (ID_Rating),
    KEY fk_rating_customer_idx (ID_Customer),
    KEY fk_rating_product_idx (ID_Product),
    CONSTRAINT fk_rating_customer
        FOREIGN KEY (ID_Customer)
        REFERENCES customer (ID_Customer)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_rating_product
        FOREIGN KEY (ID_Product)
        REFERENCES product_module (ID_Product)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


-- 14. PAYMENT (card-only payments)
CREATE TABLE payment (
    ID_Payment        INT NOT NULL AUTO_INCREMENT,
    ID_Purchase       INT NOT NULL,
    Payment_Method    ENUM('CARD') NOT NULL DEFAULT 'CARD',
    Card_Last4        CHAR(4) NOT NULL,
    Amount            DECIMAL(10,2) NOT NULL,
    Paid_At           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ID_Payment),
    KEY fk_payment_purchase_idx (ID_Purchase),
    CONSTRAINT fk_payment_purchase
        FOREIGN KEY (ID_Purchase)
        REFERENCES purchase (ID_Purchase)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


-- 15. LOG_EVENT (generic log table)
CREATE TABLE log_event (
    ID_Log          INT NOT NULL AUTO_INCREMENT,
    Event_Datetime  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    DB_User         VARCHAR(100) DEFAULT NULL,
    Table_Name      VARCHAR(64) NOT NULL,
    Operation_Type  ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    Entity_ID       INT DEFAULT NULL,
    Description     VARCHAR(255) DEFAULT NULL,
    PRIMARY KEY (ID_Log),
    KEY idx_log_table_op (Table_Name, Operation_Type, Event_Datetime)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


-- ==========================================
-- INSERT DATA (OPERATING PERIOD 2023-01 – 2025-11)
-- ==========================================

-- ==========================================
-- 1. COUNTRY (5 countries)
-- ==========================================
INSERT INTO country (ID_Country, Country_Name, ISO2_Code) VALUES
(1, 'Portugal', 'PT'),
(2, 'Spain',    'ES'),
(3, 'France',   'FR'),
(4, 'Italy',    'IT'),
(5, 'Austria',  'AT');

-- ==========================================
-- 2. CITY (2 cities per country)
-- ==========================================
INSERT INTO city (ID_City, ID_Country, City_Name) VALUES
(1, 1, 'Lisboa'),
(2, 1, 'Porto'),
(3, 2, 'Madrid'),
(4, 2, 'Barcelona'),
(5, 3, 'Paris'),
(6, 3, 'Lyon'),
(7, 4, 'Rome'),
(8, 4, 'Milan'),
(9, 5, 'Vienna'),
(10,5, 'Salzburg');

-- ==========================================
-- 3. COMPANY (5 offices: PT HQ + ES/FR/IT/AT branches)
-- ==========================================
INSERT INTO company
(ID_Company, Company_Name, Legal_Name, Tax_ID, Country_Code, ID_City, Street_Address, ZipCode, Phone, Email, Website) VALUES
-- Portugal HQ – Lisbon
(1,
 'Polyglotica.AI Portugal HQ',
 'Polyglotica.AI Portugal Lda',
 'PT-123456789',
 'PT',
 1,  -- Lisbon
 'Rua Augusta 50, Lisboa Centro',
 '1100-053',
 '+351-210-000-001',
 'pt-office@polyglotica.ai',
 'https://polyglotica.ai/pt'),

-- Spain office – Madrid
(2,
 'Polyglotica.AI Spain',
 'Polyglotica.AI Spain SL',
 'ES-B12345678',
 'ES',
 3,  -- Madrid
 'Calle Mayor 10',
 '28013',
 '+34-910-000-002',
 'es-office@polyglotica.ai',
 'https://polyglotica.ai/es'),

-- France office – Paris
(3,
 'Polyglotica.AI France',
 'Polyglotica.AI France SAS',
 'FR-123456789',
 'FR',
 5, -- Paris
 'Rue de Rivoli 100',
 '75001',
 '+33-1-0000-0003',
 'fr-office@polyglotica.ai',
 'https://polyglotica.ai/fr'),

-- Italy office – Rome
(4,
 'Polyglotica.AI Italy',
 'Polyglotica.AI Italia SRL',
 'IT-123456789',
 'IT',
 7, -- Rome
 'Via del Corso 200',
 '00186',
 '+39-06-0000-0004',
 'it-office@polyglotica.ai',
 'https://polyglotica.ai/it'),

-- Austria office – Vienna
(5,
 'Polyglotica.AI Austria',
 'Polyglotica.AI Austria GmbH',
 'AT-123456789',
 'AT',
 9, -- Vienna
 'Kärntner Straße 100',
 '1010',
 '+43-1-0000-0005',
 'at-office@polyglotica.ai',
 'https://polyglotica.ai/at');


-- ==========================================
-- 4. LANGUAGE (learning languages)
-- ==========================================
INSERT INTO language (ID_Language, Language_Code, Language_Name) VALUES
(1, 'PT', 'Portuguese'),
(2, 'ES', 'Spanish'),
(3, 'FR', 'French');

-- ==========================================
-- 5. MODULE_LEVEL (core + supplements)
-- ==========================================
INSERT INTO module_level (ID_Level, Level_Code, Level_Name, Is_Core, Display_Order) VALUES
(1, 'BEGINNER',          'Beginner',             1, 1),
(2, 'INTERMEDIATE',      'Intermediate',         1, 2),
(3, 'UPPER_INTERMEDIATE','Upper Intermediate',   1, 3),
(4, 'ADVANCED',          'Advanced',             1, 4),
(5, 'PROFESSIONAL',      'Professional',         1, 5),
(6, 'WORD_CARDS',        'Word Cards',           0, 6),
(7, 'CROSSWORDS',        'Crosswords',           0, 7);

-- ==========================================
-- 6. PRODUCT_MODULE (21 products, with stock)
--     PT: 1–7, ES: 8–14, FR: 15–21
-- ==========================================
INSERT INTO product_module
(ID_Product, ID_Language, ID_Level, Product_Name, Base_Price, Stock_Qty, Is_Active) VALUES
-- Portuguese
(1, 1, 1, 'Portuguese Beginner',            30.00, 100, 1),
(2, 1, 2, 'Portuguese Intermediate',        35.00, 100, 1),
(3, 1, 3, 'Portuguese Upper Intermediate',  40.00, 100, 1),
(4, 1, 4, 'Portuguese Advanced',            45.00, 100, 1),
(5, 1, 5, 'Portuguese Professional',        50.00, 100, 1),
(6, 1, 6, 'Portuguese Word Cards',          10.00, 100, 1),
(7, 1, 7, 'Portuguese Crosswords',           8.00, 100, 1),

-- Spanish
(8,  2, 1, 'Spanish Beginner',              30.00, 100, 1),
(9,  2, 2, 'Spanish Intermediate',          35.00, 100, 1),
(10, 2, 3, 'Spanish Upper Intermediate',    40.00, 100, 1),
(11, 2, 4, 'Spanish Advanced',              45.00, 100, 1),
(12, 2, 5, 'Spanish Professional',          50.00, 100, 1),
(13, 2, 6, 'Spanish Word Cards',            10.00, 100, 1),
(14, 2, 7, 'Spanish Crosswords',             8.00, 100, 1),

-- French
(15, 3, 1, 'French Beginner',               30.00, 100, 1),
(16, 3, 2, 'French Intermediate',           35.00, 100, 1),
(17, 3, 3, 'French Upper Intermediate',     40.00, 100, 1),
(18, 3, 4, 'French Advanced',               45.00, 100, 1),
(19, 3, 5, 'French Professional',           50.00, 100, 1),
(20, 3, 6, 'French Word Cards',             10.00, 100, 1),
(21, 3, 7, 'French Crosswords',              8.00, 100, 1);

-- ==========================================
-- 7. PROMOTION
-- ==========================================
INSERT INTO promotion
(ID_Promotion, Promotion_Code, Promotion_Name, Promotion_Type, Start_Date, End_Date, Discount_Percent, Is_Active) VALUES
(1, 'NY2023',   'New Year 2023',          'SEASONAL', '2023-01-01', '2023-01-15', 20.00, 0),
(2, 'SPRING23', 'Spring 2023',            'SEASONAL', '2023-03-01', '2023-03-31', 15.00, 0),
(3, 'BF2023',   'Black Friday 2023',      'EVENT',    '2023-11-24', '2023-11-27', 40.00, 0),
(4, 'BTS2024',  'Back to School 2024',    'SEASONAL', '2024-09-01', '2024-09-30', 20.00, 0),
(5, 'NY2024',   'New Year 2024',          'SEASONAL', '2024-01-01', '2024-01-15', 20.00, 0),
(6, 'SPRING24', 'Spring 2024',            'SEASONAL', '2024-03-01', '2024-03-31', 15.00, 0),
(7, 'BF2024',   'Black Friday 2024',      'EVENT',    '2024-11-29', '2024-12-02', 40.00, 0),
(8, 'NY2025',   'New Year 2025',          'SEASONAL', '2025-01-01', '2025-01-15', 20.00, 1),
(9, 'SPRING25', 'Spring 2025',            'SEASONAL', '2025-03-01', '2025-03-31', 15.00, 1),
(10,'BF2025',   'Black Friday 2025',      'EVENT',    '2025-11-28', '2025-11-30', 40.00, 1);

-- ==========================================
-- 8. PROMOTION_PRODUCT
-- ==========================================
INSERT INTO promotion_product (ID_Promotion, ID_Product) VALUES
(1, 1),(1, 8),(1, 15),
(2, 2),(2, 9),(2, 16),
(3, 5),(3,12),(3,19),
(4, 1),(4,10),(4,17),
(5, 2),(5, 9),(5,16),
(6, 3),(6,10),(6,17),
(8, 1),(8, 2),(8, 3),
(9, 15),(9,16),(9,17),
(10,5),(10,12),(10,19);

-- ==========================================
-- 9. CUSTOMERS (20 total, 4 per country)
-- ==========================================
INSERT INTO customer
(ID_Customer, First_Name, Last_Name, Email, Gender, Birthdate,
 Street_Address, ZipCode, ID_City, Registration_Datetime)
VALUES
-- Portugal (PT, cities 1–2)
(1,  'Ana',      'Silva',      'ana.silva@example.com',      'F', '1990-01-10',
 'Rua de São José 1',      '1150-321', 1, '2023-01-10 09:30:00'),
(2,  'Bruno',    'Costa',      'bruno.costa@example.com',    'M', '1988-05-12',
 'Rua do Alecrim 2',       '1200-018', 1, '2023-01-15 11:00:00'),
(3,  'Carla',    'Gomes',      'carla.gomes@example.com',    'F', '1995-03-20',
 'Rua da Ribeira 3',       '4000-123', 2, '2023-02-01 10:15:00'),
(4,  'Daniel',   'Ferreira',   'daniel.ferreira@example.com','M', '1985-07-08',
 'Av. dos Aliados 4',      '4000-321', 2, '2023-02-18 14:20:00'),

-- Spain (ES, cities 3–4)
(5,  'Eduardo',  'Lopez',      'eduardo.lopez@example.com',  'M', '1987-02-15',
 'Calle Mayor 5',          '28013',    3, '2023-03-01 09:00:00'),
(6,  'Lucia',    'Garcia',     'lucia.garcia@example.com',   'F', '1992-11-30',
 'Gran Via 6',             '28010',    3, '2023-03-12 10:45:00'),
(7,  'Carlos',   'Martinez',   'carlos.martinez@example.com','M', '1990-09-25',
 'Carrer de Sants 7',      '08028',    4, '2023-04-02 08:30:00'),
(8,  'Marta',    'Sanchez',    'marta.sanchez@example.com',  'F', '1993-04-18',
 'La Rambla 8',            '08001',    4, '2023-04-20 10:10:00'),

-- France (FR, cities 5–6)
(9,  'Claire',   'Dubois',     'claire.dubois@example.com',  'F', '1989-02-14',
 'Rue de Rivoli 9',        '75001',    5, '2023-05-05 11:30:00'),
(10, 'Jean',     'Martin',     'jean.martin@example.com',    'M', '1984-06-09',
 'Boulevard Saint-Michel 10','75005',  5, '2023-05-25 15:00:00'),
(11, 'Sophie',   'Moreau',     'sophie.moreau@example.com',  'F', '1991-08-22',
 'Rue de la République 11','69002',    6, '2023-06-10 09:00:00'),
(12, 'Pierre',   'Leroy',      'pierre.leroy@example.com',   'M', '1982-01-30',
 'Place Bellecour 12',     '69002',    6, '2023-06-20 11:45:00'),

-- Italy (IT, cities 7–8)
(13, 'Giulia',   'Rossi',      'giulia.rossi@example.com',   'F', '1994-02-02',
 'Via del Corso 13',       '00186',    7, '2023-07-05 13:00:00'),
(14, 'Marco',    'Bianchi',    'marco.bianchi@example.com',  'M', '1990-05-05',
 'Via Nazionale 14',       '00184',    7, '2023-07-18 17:20:00'),
(15, 'Luca',     'Ferrari',    'luca.ferrari@example.com',   'M', '1993-09-09',
 'Via Torino 15',          '20123',    8, '2023-08-03 19:00:00'),
(16, 'Sara',     'Romano',     'sara.romano@example.com',    'F', '1991-10-01',
 'Corso Buenos Aires 16',  '20124',    8, '2023-08-25 08:00:00'),

-- Austria (AT, cities 9–10)
(17, 'Anna',     'Huber',      'anna.huber@example.com',     'F', '1988-07-07',
 'Kärntner Straße 17',     '1010',     9, '2023-09-10 12:15:00'),
(18, 'Thomas',   'Müller',     'thomas.mueller@example.com', 'M', '1986-11-11',
 'Ringstraße 18',          '1010',     9, '2023-09-28 14:40:00'),
(19, 'Stefan',   'Gruber',     'stefan.gruber@example.com',  'M', '1983-12-24',
 'Getreidegasse 19',       '5020',    10, '2023-10-15 16:05:00'),
(20, 'Eva',      'Wagner',     'eva.wagner@example.com',     'F', '1988-03-03',
 'Linzer Gasse 20',        '5020',    10, '2023-10-30 18:30:00');

-- ==========================================
-- 10. TAX_RATE (VAT per country)
-- ==========================================
INSERT INTO tax_rate (ID_Tax, Tax_Name, Country_Code, Tax_Percent) VALUES
(1, 'PT Standard VAT', 'PT', 23.00),
(2, 'ES Standard VAT', 'ES', 21.00),
(3, 'FR Standard VAT', 'FR', 20.00),
(4, 'IT Standard VAT', 'IT', 22.00),
(5, 'AT Standard VAT', 'AT', 20.00);


-- ==========================================
-- 11. PURCHASE (20 invoices)
--    Discounted purchases:
--      P3, P7, P19 -> promo 6 (Spring24, 15%)
--      P6, P10     -> promo 5 (NY2024, 20%)
-- ==========================================
INSERT INTO purchase
(ID_Purchase, ID_Customer, ID_Company, ID_Promotion, ID_Tax, Purchase_Datetime) VALUES
-- PT customers (1–4) → PT office (1), PT VAT (1)
(1,  1, 1, NULL, 1, '2023-11-10 10:00:00'),
(2,  2, 1, NULL, 1, '2024-02-15 11:30:00'),
(3,  3, 1,  6,   1, '2024-03-20 09:45:00'),  -- Spring24 (15%)
(4,  4, 1, NULL, 1, '2025-03-25 20:10:00'),

-- ES customers (5–8) → ES office (2), ES VAT (2)
(5,  5, 2, NULL, 2, '2023-12-05 19:00:00'),
(6,  6, 2,  5,   2, '2024-01-08 10:00:00'),  -- NY2024 (20%)
(7,  7, 2,  6,   2, '2024-03-22 14:30:00'),  -- Spring24 (15%)
(8,  8, 2, NULL, 2, '2025-04-01 09:20:00'),

-- FR customers (9–12) → FR office (3), FR VAT (3)
(9,  9, 3, NULL, 3, '2023-12-20 16:00:00'),
(10,10, 3,  5,   3, '2024-01-12 09:40:00'),  -- NY2024 (20%)
(11,11, 3, NULL, 3, '2024-03-28 18:15:00'),
(12,12, 3, NULL, 3, '2025-03-30 11:05:00'),

-- IT customers (13–16) → IT office (4), IT VAT (4)
(13,13, 4, NULL, 4, '2023-11-15 15:10:00'),
(14,14, 4, NULL, 4, '2024-03-10 10:20:00'),
(15,15, 4, NULL, 4, '2025-03-18 19:50:00'),
(16,16, 4, NULL, 4, '2025-04-05 08:30:00'),

-- AT customers (17–20) → AT office (5), AT VAT (5)
(17,17, 5, NULL, 5, '2023-12-01 13:25:00'),
(18,18, 5, NULL, 5, '2024-01-20 17:45:00'),
(19,19, 5,  6,   5, '2024-03-29 09:55:00'),  -- Spring24 (15%)
(20,20, 5, NULL, 5, '2025-03-29 20:45:00');

-- ==========================================
-- 12. PURCHASE_ITEM
--    Base prices (from product_module):
--      1:30, 2:35, 3:40, 4:45, 5:50, 6:10, 7:8,
--      8:30, 9:35,10:40,11:45,12:50,13:10,14:8,
--     15:30,16:35,17:40,18:45,19:50,20:10,21:8
--
--    Discounts:
--      Promo 5 (NY2024, 20%):  Unit_Price = 0.80 * Base
--        -> products 2, 9, 16
--      Promo 6 (Spring24, 15%): Unit_Price = 0.85 * Base
--        -> products 3, 10, 17
--
--    Discounted lines:
--      P3:  product 10 -> 40 * 0.85 = 34.00
--      P6:  product 16 -> 35 * 0.80 = 28.00
--      P7:  product  3 -> 40 * 0.85 = 34.00
--      P10: product  9 -> 35 * 0.80 = 28.00
--      P19: product 17 -> 40 * 0.85 = 34.00
-- ==========================================
INSERT INTO purchase_item
(ID_PurchaseItem, ID_Purchase, ID_Product, Quantity, Unit_Price) VALUES
-- PT customers (1–4) → ES/FR modules, no discount except P3
(1,  1,  8, 2, 30.00),   -- Spanish Beginner (base)
(2,  1, 13, 1, 10.00),   -- Spanish Word Cards (base)
(3,  2, 15, 1, 30.00),   -- French Beginner (base)
(4,  3, 10, 1, 34.00),   -- Spanish Upper Intermediate (discounted from 40)
(5,  4, 18, 1, 45.00),   -- French Advanced (base)

-- ES customers (5–8) → PT/FR modules, P6 & P7 discounted
(6,  5,  1, 1, 30.00),   -- Portuguese Beginner (base)
(7,  5,  6, 1, 10.00),   -- Portuguese Word Cards (base)
(8,  6, 16, 1, 28.00),   -- French Intermediate (discounted from 35)
(9,  7,  3, 1, 34.00),   -- Portuguese Upper Intermediate (discounted from 40)
(10, 8, 19, 1, 50.00),   -- French Professional (base)

-- FR customers (9–12) → PT/ES modules, P10 discounted
(11, 9,  2, 1, 35.00),   -- Portuguese Intermediate (base)
(12, 9,  7, 1,  8.00),   -- Portuguese Crosswords (base)
(13,10,  9, 1, 28.00),   -- Spanish Intermediate (discounted from 35)
(14,11,  4, 1, 45.00),   -- Portuguese Advanced (base)
(15,12, 12, 1, 50.00),   -- Spanish Professional (base)

-- IT customers (13–16) → any language, all full price
(16,13,  1, 1, 30.00),   -- Portuguese Beginner (base)
(17,13,  8, 1, 30.00),   -- Spanish Beginner (base)
(18,14, 15, 1, 30.00),   -- French Beginner (base)
(19,15, 11, 1, 45.00),   -- Spanish Advanced (base)
(20,16,  5, 1, 50.00),   -- Portuguese Professional (base)

-- AT customers (17–20) → any language, P19 discounted
(21,17,  3, 1, 40.00),   -- Portuguese Upper Intermediate (base)
(22,17, 20, 1, 10.00),   -- French Word Cards (base)
(23,18,  9, 1, 35.00),   -- Spanish Intermediate (base)
(24,19, 17, 1, 34.00),   -- French Upper Intermediate (discounted from 40)
(25,20,  2, 1, 35.00);   -- Portuguese Intermediate (base)

-- ==========================================
-- 13. RATING (re-using simple examples)
-- ==========================================
INSERT INTO rating
(ID_Rating, ID_Customer, ID_Product, Rating_Value, Rating_Datetime, Bonus_Granted) VALUES
(1,  1,  8, 5, '2023-11-15 12:00:00', 1),
(2,  2, 15, 4, '2024-02-20 13:10:00', 1),
(3,  3, 10, 5, '2024-03-25 10:30:00', 1),
(4,  4, 18, 4, '2025-03-30 21:00:00', 0),
(5,  5,  1, 5, '2023-12-10 18:15:00', 1),
(6,  6, 16, 4, '2024-01-15 11:05:00', 1),
(7,  7,  3, 5, '2024-03-25 09:30:00', 1),
(8,  8, 19, 3, '2025-04-05 20:10:00', 0),
(9,  9,  2, 4, '2023-12-22 16:40:00', 1),
(10,10,  9, 5, '2024-01-18 19:20:00', 1),
(11,11,  4, 4, '2024-03-30 12:10:00', 0),
(12,12, 12, 5, '2025-04-02 14:05:00', 1),
(13,13,  1, 4, '2023-11-20 13:15:00', 1),
(14,14, 15, 5, '2024-03-15 17:10:00', 1),
(15,15, 11, 3, '2025-03-20 20:00:00', 0),
(16,16,  5, 4, '2025-04-07 10:50:00', 1),
(17,17,  3, 5, '2023-12-05 09:45:00', 1),
(18,18, 20, 4, '2024-01-25 11:25:00', 1),
(19,19, 17, 5, '2024-03-31 22:00:00', 1),
(20,20,  2, 4, '2025-03-31 09:10:00', 1);

-- ==========================================
-- 14. PAYMENT
--    Totals per purchase (after discount):
--      P1: 30 * 2 + 10  = 70.00
--      P2: 30           = 30.00
--      P3: 34           = 34.00  (disc)
--      P4: 45           = 45.00
--      P5: 30 + 10      = 40.00
--      P6: 28           = 28.00  (disc)
--      P7: 34           = 34.00  (disc)
--      P8: 50           = 50.00
--      P9: 35 + 8       = 43.00
--      P10: 28          = 28.00  (disc)
--      P11: 45          = 45.00
--      P12: 50          = 50.00
--      P13: 30 + 30     = 60.00
--      P14: 30          = 30.00
--      P15: 45          = 45.00
--      P16: 50          = 50.00
--      P17: 40 + 10     = 50.00
--      P18: 35          = 35.00
--      P19: 34          = 34.00  (disc)
--      P20: 35          = 35.00
-- ==========================================
INSERT INTO payment
(ID_Payment, ID_Purchase, Payment_Method, Card_Last4, Amount, Paid_At) VALUES
(1,  1, 'CARD', '1111',  70.00, '2023-11-10 10:05:00'),
(2,  2, 'CARD', '2222',  30.00, '2024-02-15 11:35:00'),
(3,  3, 'CARD', '3333',  34.00, '2024-03-20 09:50:00'),
(4,  4, 'CARD', '4444',  45.00, '2025-03-25 20:15:00'),
(5,  5, 'CARD', '5555',  40.00, '2023-12-05 19:05:00'),
(6,  6, 'CARD', '6666',  28.00, '2024-01-08 10:05:00'),
(7,  7, 'CARD', '7777',  34.00, '2024-03-22 14:35:00'),
(8,  8, 'CARD', '8888',  50.00, '2025-04-01 09:25:00'),
(9,  9, 'CARD', '9999',  43.00, '2023-12-20 16:05:00'),
(10,10, 'CARD', '0001',  28.00, '2024-01-12 09:45:00'),
(11,11, 'CARD', '0002',  45.00, '2024-03-28 18:20:00'),
(12,12, 'CARD', '0003',  50.00, '2025-03-30 11:10:00'),
(13,13, 'CARD', '0004',  60.00, '2023-11-15 15:15:00'),
(14,14, 'CARD', '0005',  30.00, '2024-03-10 10:25:00'),
(15,15, 'CARD', '0006',  45.00, '2025-03-18 19:55:00'),
(16,16, 'CARD', '0007',  50.00, '2025-04-05 08:35:00'),
(17,17, 'CARD', '0008',  50.00, '2023-12-01 13:30:00'),
(18,18, 'CARD', '0009',  35.00, '2024-01-20 17:50:00'),
(19,19, 'CARD', '0010',  34.00, '2024-03-29 10:00:00'),
(20,20, 'CARD', '0011',  35.00, '2025-03-29 20:50:00');

-- ==========================================
-- 15. LOG_EVENT (simple example logs)
-- ==========================================
INSERT INTO log_event
(ID_Log, Event_Datetime, DB_User, Table_Name, Operation_Type, Entity_ID, Description) VALUES
(1,  '2023-01-01 09:00:00', 'root@localhost', 'product_module', 'INSERT', 1,  'Initial load of Portuguese modules'),
(2,  '2023-01-01 09:05:00', 'root@localhost', 'product_module', 'INSERT', 8,  'Initial load of Spanish modules'),
(3,  '2023-01-01 09:10:00', 'root@localhost', 'product_module', 'INSERT', 15, 'Initial load of French modules'),
(4,  '2023-11-10 10:02:00', 'root@localhost', 'purchase',       'INSERT', 1,  'Purchase 1 created'),
(5,  '2023-11-10 10:03:00', 'root@localhost', 'payment',        'INSERT', 1,  'Payment for purchase 1'),
(6,  '2023-12-05 19:02:00', 'root@localhost', 'purchase',       'INSERT', 5,  'Purchase 5 created'),
(7,  '2023-12-20 16:02:00', 'root@localhost', 'purchase',       'INSERT', 9,  'Purchase 9 created'),
(8,  '2024-01-08 10:02:00', 'root@localhost', 'purchase',       'INSERT', 6,  'Purchase 6 created'),
(9,  '2024-03-20 09:47:00', 'root@localhost', 'purchase',       'INSERT', 3,  'Purchase 3 created'),
(10, '2025-03-30 11:07:00', 'root@localhost', 'purchase',       'INSERT', 12, 'Purchase 12 created'),
(11, '2025-03-29 20:47:00', 'root@localhost', 'purchase',       'INSERT', 20, 'Purchase 20 created'),
(12, '2025-11-30 09:05:00', 'root@localhost', 'promotion',      'UPDATE', 10, 'BF 2025 promotion closed'),
(13, '2025-11-30 09:15:00', 'root@localhost', 'promotion',      'UPDATE', 9,  'Spring 2025 promotion deactivated');
