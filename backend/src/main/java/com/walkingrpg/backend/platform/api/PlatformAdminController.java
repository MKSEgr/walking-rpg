package com.walkingrpg.backend.platform.api;

import java.util.List;
import java.util.Map;

import com.walkingrpg.backend.platform.application.PlatformAdminService;
import com.walkingrpg.backend.platform.push.PushDeliveryResult;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class PlatformAdminController {

    private static final String USER_HEADER = "X-User-Id";
    private static final String ACTOR_HEADER = "X-Mock-User";

    private final PlatformAdminService service;

    public PlatformAdminController(PlatformAdminService service) {
        this.service = service;
    }

    @PostMapping("/telemetry/events")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public Map<String, Object> telemetry(
            @RequestHeader(value = USER_HEADER, required = false) String userId,
            @Valid @RequestBody TelemetryEventRequest request
    ) {
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
            @RequestHeader(value = USER_HEADER, required = false) String userId,
            @Valid @RequestBody CrashReportRequest request
    ) {
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
            @RequestHeader(USER_HEADER) String userId,
            @Valid @RequestBody PushRegistrationRequest request
    ) {
        service.registerPush(
                userId,
                request.deviceId(),
                request.platform(),
                request.provider(),
                request.token()
        );
        return Map.of("registered", true);
    }

    @GetMapping("/account/export")
    public Map<String, Object> exportAccount(
            @RequestHeader(USER_HEADER) String userId
    ) {
        return service.exportAccount(userId);
    }

    @DeleteMapping("/account")
    public Map<String, Object> deleteAccount(
            @RequestHeader(USER_HEADER) String userId
    ) {
        return Map.of("deleted", service.deleteAccount(userId));
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

    @GetMapping("/admin/platform/diagnostics/crashes")
    public List<Map<String, Object>> crashes(
            @RequestParam(defaultValue = "100") int limit
    ) {
        return service.crashReports(limit);
    }

    @PutMapping("/admin/platform/remote-config")
    public Map<String, Object> updateRemoteConfig(
            @RequestHeader(value = ACTOR_HEADER, defaultValue = "admin") String actor,
            @Valid @RequestBody RemoteConfigUpdateRequest request
    ) {
        return service.updateRemoteConfig(actor, request.version(), request.config());
    }

    @PostMapping("/admin/platform/content-releases")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> publishContent(
            @RequestHeader(value = ACTOR_HEADER, defaultValue = "admin") String actor,
            @Valid @RequestBody ContentReleaseRequest request
    ) {
        return service.publishContent(
                actor,
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
            @RequestHeader(value = ACTOR_HEADER, defaultValue = "admin") String actor,
            @Valid @RequestBody TesterCohortRequest request
    ) {
        service.upsertTester(
                actor,
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
