{{ config(
    materialized = 'view'
) }}

WITH source AS (
    SELECT * FROM {{ source('raw', 'tbl_vehicle') }}
),

renamed AS (
    SELECT
        -- Primary key
        vehicle_id,
        
        -- Foreign keys
        make_id,
        model_id,
        type_id,
        
        -- Vehicle details
        vin,
        year,
        color,
        mileage,
        
        -- Metadata
        created_at,
        updated_at,
        
        -- Snapshot timestamp from the export process
        _snapshot_timestamp
    FROM source
)

SELECT * FROM renamed

