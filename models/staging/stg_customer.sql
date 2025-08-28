{{ config(
    materialized = 'view'
) }}

WITH source AS (
    SELECT * FROM {{ source('raw', 'tbl_customer') }}
),

renamed AS (
    SELECT
        -- Primary key
        customer_id,
        
        -- Customer details
        first_name,
        last_name,
        email,
        phone,
        address,
        city,
        state,
        zip_code,
        
        -- Metadata
        created_at,
        updated_at,
        
        -- Snapshot timestamp from the export process
        _snapshot_timestamp
    FROM source
)

SELECT * FROM renamed

