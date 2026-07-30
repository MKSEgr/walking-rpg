package com.walkingrpg.backend.platform.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "walking-rpg.providers")
public class PlatformProviderProperties {

    private String payment = "disabled";
    private String push = "disabled";

    public String getPayment() {
        return payment;
    }

    public void setPayment(String payment) {
        this.payment = payment;
    }

    public String getPush() {
        return push;
    }

    public void setPush(String push) {
        this.push = push;
    }
}
