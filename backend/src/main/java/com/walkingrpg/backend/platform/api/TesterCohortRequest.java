package com.walkingrpg.backend.platform.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record TesterCohortRequest(
        @NotBlank @Size(max = 64) String cohortCode,
        @NotBlank @Size(max = 128) String userId,
        @NotBlank @Size(max = 32) String status,
        @Size(max = 2000) String notes
) {
}
