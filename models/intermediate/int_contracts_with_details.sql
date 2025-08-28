{{ config(
    materialized = 'view'
) }}

WITH contracts AS (
    SELECT * FROM {{ ref('stg_contract') }}
),

customers AS (
    SELECT * FROM {{ ref('stg_customer') }}
),

vehicles AS (
    SELECT * FROM {{ ref('stg_vehicle') }}
),

contracts_with_details AS (
    SELECT
        -- Contract information
        c.contract_id,
        c.contract_number,
        c.contract_date,
        c.effective_date,
        c.expiration_date,
        c.term_months,
        c.contract_status,
        c.retail_price,
        c.dealer_cost,
        
        -- Customer information
        cust.customer_id,
        cust.first_name AS customer_first_name,
        cust.last_name AS customer_last_name,
        cust.email AS customer_email,
        cust.state AS customer_state,
        
        -- Vehicle information
        v.vehicle_id,
        v.vin,
        v.year AS vehicle_year,
        v.mileage,
        
        -- Metadata
        c.created_at,
        c.updated_at,
        c._snapshot_timestamp
    FROM contracts c
    LEFT JOIN customers cust ON c.customer_id = cust.customer_id
    LEFT JOIN vehicles v ON c.vehicle_id = v.vehicle_id
)

SELECT * FROM contracts_with_details

