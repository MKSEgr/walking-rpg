UPDATE remote_config_snapshot
SET config_json = jsonb_set(
        jsonb_set(
            config_json,
            '{sandboxPaymentsEnabled}',
            'false'::jsonb,
            true
        ),
        '{backgroundHealthSyncEnabled}',
        'false'::jsonb,
        true
    )
WHERE config_json -> 'sandboxPaymentsEnabled' IS DISTINCT FROM 'false'::jsonb
   OR config_json -> 'backgroundHealthSyncEnabled' IS DISTINCT FROM 'false'::jsonb;
