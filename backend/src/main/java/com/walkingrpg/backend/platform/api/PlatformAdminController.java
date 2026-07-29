package com.walkingrpg.backend.platform.api;

import java.util.List;
import java.util.Map;

import com.walkingrpg.backend.platform.application.PlatformAdminService;
import com.walkingrpg.backend.platform.application.AccountDeletionReceipt;
import com.walkingrpg.backend.platform.analytics.FirstJourneyAnalyticsService;
import com.walkingrpg.backend.platform.analytics.FirstJourneyAnalyticsSnapshot;
import com.walkingrpg.backend.platform.push.PushDeliveryResult;
import com.walkingrpg.backend.security.RequestIdentityProvider;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class PlatformAdminController {

    private final PlatformAdminService service;
    private final FirstJourneyAnalyticsService firstJourneyAnalyticsService;
    private final RequestIdentityProvider identityProvider;

    public PlatformAdminController(
            PlatformAdminService service,
            FirstJourneyAnalyticsService firstJourneyAnalyticsService,
            RequestIdentityProvider identityProvider
    ) {
        this.service = service;
        this.firstJourneyAnalyticsService = firstJourneyAnalyticsService;
        this.identityProvider = identityProvider;
    }

    @PostMapping("/telemetry/events")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public Map<String, Object> telemetry(
            @Valid @RequestBody TelemetryEventRequest request
    ) {
        String userId = identityProvider.currentIdentity()
                .map(identity -> identity.userId())
                .orElse(null);
        service.recordEvent(
                userId,
                request.eventName(),
                request.occurredAt(),
                request.attributes()
        );
        return Map.of("accepted", true);
    }

    @PostMapping("/diagnostics/crashes")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public Map<String, Object> crash(
            @Valid @RequestBody CrashReportRequest request
    ) {
        String userId = identityProvider.currentIdentity()
                .map(identity -> identity.userId())
                .orElse(null);
        service.recordCrash(
                userId,
                request.platform(),
                request.appVersion(),
                request.errorType(),
                request.message(),
                request.stackTrace(),
                request.context(),
                request.occurredAt()
        );
        return Map.of("accepted", true);
    }

    @PostMapping("/push/registrations")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> registerPush(
            @Valid @RequestBody PushRegistrationRequest request
    ) {
        service.registerPush(
                identityProvider.requireIdentity().userId(),
                request.deviceId(),
                request.platform(),
                request.provider(),
                request.token()
        );
        return Map.of("registered", true);
    }

    @GetMapping("/account/export")
    public Map<String, Object> exportAccount() {
        return service.exportAccount(identityProvider.requireIdentity().userId());
    }

    @PostMapping("/account/deletion-requests")
    public AccountDeletionReceipt deleteAccount(
            @RequestHeader("Idempotency-Key") String idempotencyKey,
            @Valid @RequestBody AccountDeletionRequest request
    ) {
        return service.requestAccountDeletion(
                identityProvider.requireIdentityForAccountDeletion().userId(),
                idempotencyKey,
                request.confirmation()
        );
    }

    @GetMapping("/admin/platform/risk/assessments")
    public List<Map<String, Object>> riskAssessments(
            @RequestParam(defaultValue = "100") int limit
    ) {
        return service.riskAssessments(limit);
    }

    @GetMapping("/admin/platform/analytics/retention")
    public Map<String, Object> retention() {
        return service.retentionSummary();
    }

    @GetMapping("/admin/platform/analytics/first-journey")
    public FirstJourneyAnalyticsSnapshot firstJourney(
            @RequestParam(required = false) String cohortCode
    ) {
        return firstJourneyAnalyticsService.summary(cohortCode);
    }

    @GetMapping("/admin/platform/diagnostics/crashes")
    public List<Map<String, Object>> crashes(
            @RequestParam(defaultValue = "100") int limit
    ) {
        return service.crashReports(limit);
    }

    @PutMapping("/admin/platform/remote-config")
    public Map<String, Object> updateRemoteConfig(
            @Valid @RequestBody RemoteConfigUpdateRequest request
    ) {
        return service.updateRemoteConfig(
                identityProvider.requireIdentity().actor(),
                request.version(),
                request.config()
        );
    }

    @PostMapping("/admin/platform/content-releases")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> publishContent(
            @Valid @RequestBody ContentReleaseRequest request
    ) {
        return service.publishContent(
                identityProvider.requireIdentity().actor(),
                request.contentVersion(),
                request.releaseNotes(),
                request.content()
        );
    }

    @GetMapping("/admin/platform/content-releases")
    public List<Map<String, Object>> contentReleases() {
        return service.contentReleases();
    }

    @PostMapping("/admin/platform/push/test")
    public PushDeliveryResult testPush(@Valid @RequestBody TestPushRequest request) {
        return service.sendTestPush(request.userId(), request.title(), request.body());
    }

    @PostMapping("/admin/platform/testers")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> upsertTester(
            @Valid @RequestBody TesterCohortRequest request
    ) {
        service.upsertTester(
                identityProvider.requireIdentity().actor(),
                request.cohortCode(),
                request.userId(),
                request.status(),
                request.notes()
        );
        return Map.of("saved", true);
    }

    @GetMapping("/admin/platform/testers")
    public List<Map<String, Object>> testers(
            @RequestParam(required = false) String cohortCode
    ) {
        return service.testers(cohortCode);
    }

    @PostMapping("/admin/platform/activity-retention/cleanup")
    public Map<String, Object> cleanupRetention() {
        return Map.of("deleted", service.cleanupActivityRetention());
    }
}
