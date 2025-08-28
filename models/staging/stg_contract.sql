{{ config(
    materialized = 'view'
) }}

WITH source AS (
    SELECT * FROM {{ source('raw', 'tbl_contract') }}
),

renamed AS (
    SELECT
        -- Primary key
        contract_id,
        
        -- Foreign keys
        customer_id,
        dealership_id,
        product_id,
        vehicle_id,
        
        -- Contract details
        contract_number,
        contract_date,
        effective_date,
        expiration_date,
        term_months,
        contract_status,
        
        -- Financial details
        retail_price,
        dealer_cost,
        
        -- Metadata
        created_at,
        updated_at,
        
        -- Snapshot timestamp from the export process
        _snapshot_timestamp
    FROM source
)

SELECT * FROM renamed

