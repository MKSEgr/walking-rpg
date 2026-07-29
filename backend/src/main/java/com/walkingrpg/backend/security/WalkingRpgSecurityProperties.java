package com.walkingrpg.backend.security;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("walking-rpg.security")
public class WalkingRpgSecurityProperties {

    public enum Mode {
        DEV_HEADER,
        JWT
    }

    private Mode mode = Mode.JWT;
    private boolean demoEndpointsEnabled;
    private String rolesClaim = "roles";
    private String usernameClaim = "preferred_username";
    private String deviceClaim = "device_id";
    private String userRole = "walking-rpg-user";
    private String adminRole = "walking-rpg-admin";
    private String userScope = "walking-rpg.user";
    private String adminScope = "walking-rpg.admin";
    private Duration accountDeletionMaxAuthenticationAge = Duration.ofMinutes(5);

    public Mode getMode() {
        return mode;
    }

    public void setMode(Mode mode) {
        this.mode = mode;
    }

    public boolean isDemoEndpointsEnabled() {
        return demoEndpointsEnabled;
    }

    public void setDemoEndpointsEnabled(boolean demoEndpointsEnabled) {
        this.demoEndpointsEnabled = demoEndpointsEnabled;
    }

    public String getRolesClaim() {
        return rolesClaim;
    }

    public void setRolesClaim(String rolesClaim) {
        this.rolesClaim = rolesClaim;
    }

    public String getUsernameClaim() {
        return usernameClaim;
    }

    public void setUsernameClaim(String usernameClaim) {
        this.usernameClaim = usernameClaim;
    }

    public String getDeviceClaim() {
        return deviceClaim;
    }

    public void setDeviceClaim(String deviceClaim) {
        this.deviceClaim = deviceClaim;
    }

    public String getUserRole() {
        return userRole;
    }

    public void setUserRole(String userRole) {
        this.userRole = userRole;
    }

    public String getAdminRole() {
        return adminRole;
    }

    public void setAdminRole(String adminRole) {
        this.adminRole = adminRole;
    }

    public String getUserScope() {
        return userScope;
    }

    public void setUserScope(String userScope) {
        this.userScope = userScope;
    }

    public String getAdminScope() {
        return adminScope;
    }

    public void setAdminScope(String adminScope) {
        this.adminScope = adminScope;
    }

    public Duration getAccountDeletionMaxAuthenticationAge() {
        return accountDeletionMaxAuthenticationAge;
    }

    public void setAccountDeletionMaxAuthenticationAge(
            Duration accountDeletionMaxAuthenticationAge
    ) {
        this.accountDeletionMaxAuthenticationAge = accountDeletionMaxAuthenticationAge;
    }
}
