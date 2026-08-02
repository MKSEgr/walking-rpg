CREATE INDEX ix_platform_event_user_received_at
    ON platform_event (user_id, received_at);
