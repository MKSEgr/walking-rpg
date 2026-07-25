package com.walkingrpg.backend.activity.application;

public class ActivitySyncConflictException extends RuntimeException {

    public ActivitySyncConflictException(String message) {
        super(message);
    }
}
