package com.walkingrpg.backend.activity.domain;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

public final class ActivitySyncFingerprint {

    private ActivitySyncFingerprint() {
    }

    public static String sha256(ActivitySyncCommand command) {
        StringBuilder canonical = new StringBuilder(512);
        append(canonical, "userId", command.userId());
        append(canonical, "deviceId", command.deviceId());
        append(canonical, "localDate", command.localDate().toString());
        append(canonical, "timeZone", command.timeZone().getId());
        append(canonical, "authoritativeTotal", Long.toString(command.authoritativeTotal()));
        append(canonical, "bucketCount", Integer.toString(command.buckets().size()));

        for (int index = 0; index < command.buckets().size(); index++) {
            ActivityBucket bucket = command.buckets().get(index);
            append(canonical, "bucket[" + index + "].from", bucket.from().toString());
            append(canonical, "bucket[" + index + "].to", bucket.to().toString());
            append(canonical, "bucket[" + index + "].steps", Long.toString(bucket.steps()));
        }

        append(canonical, "syncCursor", command.syncCursor());
        append(canonical, "idempotencyKey", command.idempotencyKey());
        append(canonical, "attestation", command.attestation());

        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(
                    digest.digest(canonical.toString().getBytes(StandardCharsets.UTF_8))
            );
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is not available", exception);
        }
    }

    private static void append(StringBuilder target, String name, String value) {
        target.append(name).append('=');
        if (value == null) {
            target.append("-1:");
        } else {
            target.append(value.length()).append(':').append(value);
        }
        target.append(';');
    }
}
