package com.walkingrpg.backend.account.application;

public class AccountDeletedException extends RuntimeException {

    public AccountDeletedException() {
        super("Игровой аккаунт удалён");
    }
}
