package com.walkingrpg.backend.expedition.application;

@FunctionalInterface
public interface ExpeditionContentActivation {

    boolean isActive(String contentVersion);
}
