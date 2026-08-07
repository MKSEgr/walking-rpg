package com.walkingrpg.backend.platform.api;

import java.util.Map;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

public record ContentReleaseRequest(
        @NotBlank @Size(max = 64) String contentVersion,
        @NotBlank @Size(max = 2000) String releaseNotes,
        @NotEmpty Map<String, Object> content
) {
    public ContentReleaseRequest {
        content = content == null ? null : Map.copyOf(content);
    }
}
