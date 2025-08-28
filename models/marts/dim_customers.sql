{{ config(
    materialized = 'table'
) }}

WITH customers AS (
    SELECT * FROM {{ ref('stg_customer') }}
),

final AS (
    SELECT
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['customer_id']) }} AS customer_sk,
        
        -- Natural key
        customer_id,
        
        -- Customer attributes
        first_name,
        last_name,
        first_name || ' ' || last_name AS full_name,
        email,
        phone,
        
        -- Address information
        address,
        city,
        state,
        zip_code,
        
        -- Metadata
        created_at,
        updated_at,
        _snapshot_timestamp AS data_snapshot_date
    FROM customers
)

SELECT * FROM final

