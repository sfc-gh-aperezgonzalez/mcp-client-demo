-- ----------------------------------------
-- 1. ENVIRONMENT AND DATA SETUP
-- ----------------------------------------
CREATE DATABASE IF NOT EXISTS MCP_DEMO;
CREATE SCHEMA IF NOT EXISTS MCP_DEMO.SALES_DATA;
USE SCHEMA MCP_DEMO.SALES_DATA;

-- Ensure required warehouse exists and is running
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH WITH WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60;
USE WAREHOUSE COMPUTE_WH;

-- Table to hold the revenue data
CREATE OR REPLACE TABLE REVENUE_FACT (
    CUSTOMER_ID VARCHAR,
    REGION VARCHAR,
    PRODUCT_LINE VARCHAR,
    SALES_REP_ID VARCHAR,
    REVENUE_USD DECIMAL(10, 2),
    SALE_DATE DATE
);

-- Mock Data
INSERT INTO REVENUE_FACT (CUSTOMER_ID, REGION, PRODUCT_LINE, SALES_REP_ID, REVENUE_USD, SALE_DATE) VALUES
('CUST_A', 'WEST', 'Product_Line_X', 'JSM', 20000.00, '2025-07-15'),
('CUST_B', 'WEST', 'Product_Line_X', 'JSM', 15000.00, '2025-08-01'),
('CUST_C', 'EAST', 'Product_Line_X', 'DRS', 50000.00, '2025-09-10'),
('CUST_A', 'WEST', 'Product_Line_X', 'JSM', 5000.00, '2025-10-15'),
('CUST_E', 'WEST', 'Product_Line_X', 'JSM', 8000.00, '2025-11-01'),
('CUST_C', 'EAST', 'Product_Line_X', 'DRS', 52000.00, '2025-12-10'),
('CUST_D', 'WEST', 'Product_Line_Y', 'JSM', 11000.00, '2025-12-20');


-- ----------------------------------------
-- 2. TOOL DEFINITIONS (Cortex Agent Components)
-- ----------------------------------------

-- 2.1 SEMANTIC VIEW (Required for Cortex Analyst tool inside the Agent)
CREATE OR REPLACE SEMANTIC VIEW MCP_DEMO.SALES_DATA.REVENUE_SV
	tables (
		REVENUE_FACT comment='This table stores historical sales revenue data for a company, capturing key information about each sale, including the customer, region, product line, sales representative, revenue amount in US dollars, and sale date.'
	)
	facts (
		REVENUE_FACT.REVENUE_USD as REVENUE_USD comment='The total revenue generated in US dollars.'
	)
	dimensions (
		REVENUE_FACT.CUSTOMER_ID as CUSTOMER_ID comment='Unique identifier for the customer who generated the revenue.',
		REVENUE_FACT.PRODUCT_LINE as PRODUCT_LINE comment='Categorization of products into distinct lines, such as Product Line X and Product Line Y, to facilitate revenue tracking and analysis by product group.',
		REVENUE_FACT.REGION as REGION comment='Geographic region where the revenue was generated.',
		REVENUE_FACT.SALES_REP_ID as SALES_REP_ID comment='Unique identifier for the sales representative responsible for the revenue transaction.',
		REVENUE_FACT.SALE_DATE as SALE_DATE comment='Date on which the sale was made.'
	)
	with extension (CA='{"tables":[{"name":"REVENUE_FACT","dimensions":[{"name":"CUSTOMER_ID","sample_values":["CUST_A","CUST_B","CUST_C"]},{"name":"PRODUCT_LINE","sample_values":["Product_Line_X","Product_Line_Y"]},{"name":"REGION","sample_values":["EAST","WEST"]},{"name":"SALES_REP_ID","sample_values":["DRS","JSM"]}],"facts":[{"name":"REVENUE_USD","sample_values":["50000.00","20000.00","15000.00"]}],"time_dimensions":[{"name":"SALE_DATE","sample_values":["2025-07-15","2025-09-10","2025-08-01"]}]}]}');


-- 2.2 CORTEX AGENT 
CREATE OR REPLACE AGENT MCP_DEMO.SALES_DATA.REVENUE_TROUBLESHOOTER_AGENT
  COMMENT = 'Agent for deep analysis of revenue variances and customer drops, designed to find root causes'
  PROFILE = '{"display_name":"REVENUE_TROUBLESHOOTER_AGENT"}'
  FROM SPECIFICATION
$$
models:
  orchestration: "auto"
tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "semantic-analyst"
      description: "Use this to query and analyze sales revenue data from the semantic view"
tool_resources:
  semantic-analyst:
    semantic_view: "MCP_DEMO.SALES_DATA.REVENUE_SV"
$$
;


-- ----------------------------------------
-- 3. MCP SERVER DEFINITION
-- ----------------------------------------
CREATE OR REPLACE MCP SERVER SALES_INSIGHT_SERVER
  FROM SPECIFICATION $$
    tools:
      - title: "Revenue Troubleshooter Agent"
        identifier: "MCP_DEMO.SALES_DATA.REVENUE_TROUBLESHOOTER_AGENT" 
        name: "troubleshooter_agent"
        type: "CORTEX_AGENT_RUN"
        description: "Agent to find the root cause of revenue decline and identify high-value customer drops."
  $$;

