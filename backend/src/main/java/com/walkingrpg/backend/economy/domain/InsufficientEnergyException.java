package com.walkingrpg.backend.economy.domain;

public class InsufficientEnergyException extends RuntimeException {

    private final long availableEnergy;
    private final long requiredEnergy;

    public InsufficientEnergyException(long availableEnergy, long requiredEnergy) {
        super("Недостаточно энергии для операции");
        this.availableEnergy = availableEnergy;
        this.requiredEnergy = requiredEnergy;
    }

    public long availableEnergy() {
        return availableEnergy;
    }

    public long requiredEnergy() {
        return requiredEnergy;
    }
}
