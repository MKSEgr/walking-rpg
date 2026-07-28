package com.walkingrpg.backend.security;

public class MissingDeviceIdentityException extends RuntimeException {

    public MissingDeviceIdentityException() {
        super("Токен не содержит стабильный идентификатор устройства");
    }
}
