{{ config(
    materialized = 'table'
) }}

WITH contracts_with_details AS (
    SELECT * FROM {{ ref('int_contracts_with_details') }}
),

final AS (
    SELECT
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['contract_id', 'customer_id', 'vehicle_id']) }} AS contract_sk,
        
        -- Natural keys
        contract_id,
        customer_id,
        vehicle_id,
        
        -- Contract details
        contract_number,
        contract_date,
        effective_date,
        expiration_date,
        term_months,
        contract_status,
        
        -- Financial metrics
        retail_price,
        dealer_cost,
        (retail_price - dealer_cost) AS gross_profit,
        
        -- Customer information
        customer_first_name,
        customer_last_name,
        customer_email,
        customer_state,
        
        -- Vehicle information
        vin,
        vehicle_year,
        mileage,
        
        -- Date dimensions
        {{ dbt_utils.date_trunc('month', 'contract_date') }} AS contract_month,
        {{ dbt_utils.date_trunc('quarter', 'contract_date') }} AS contract_quarter,
        {{ dbt_utils.date_trunc('year', 'contract_date') }} AS contract_year,
        
        -- Metadata
        created_at,
        updated_at,
        _snapshot_timestamp AS data_snapshot_date
    FROM contracts_with_details
)

SELECT * FROM final

