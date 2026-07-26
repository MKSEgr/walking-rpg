package com.walkingrpg.backend.economy.infrastructure;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

import com.walkingrpg.backend.economy.domain.EconomyCredit;
import com.walkingrpg.backend.economy.domain.EconomyCurrency;
import com.walkingrpg.backend.economy.domain.EconomyDebit;
import com.walkingrpg.backend.economy.domain.EconomyLedgerConflictException;
import com.walkingrpg.backend.economy.domain.InsufficientEnergyException;
import com.walkingrpg.backend.economy.domain.WalletSnapshot;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcEconomyRepository implements EconomyRepository {

    private final JdbcTemplate jdbcTemplate;

    public JdbcEconomyRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public WalletSnapshot currentBalance(
            String userId,
            EconomyCurrency currency,
            Instant observedAt
    ) {
        ensureWallet(userId, currency, observedAt);
        return lockWallet(userId, currency)
                .orElseThrow(() -> new IllegalStateException("Кошелёк не был создан"));
    }

    @Override
    public WalletSnapshot applyCredit(EconomyCredit credit) {
        return applyChange(
                credit.userId(),
                credit.currency(),
                credit.amount(),
                credit.reasonCode(),
                credit.sourceType(),
                credit.sourceKey(),
                credit.occurredAt(),
                true
        );
    }

    @Override
    public WalletSnapshot applyDebit(EconomyDebit debit) {
        return applyChange(
                debit.userId(),
                debit.currency(),
                -debit.amount(),
                debit.reasonCode(),
                debit.sourceType(),
                debit.sourceKey(),
                debit.occurredAt(),
                false
        );
    }

    private WalletSnapshot applyChange(
            String userId,
            EconomyCurrency currency,
            long signedAmount,
            String reasonCode,
            String sourceType,
            String sourceKey,
            Instant occurredAt,
            boolean createWallet
    ) {
        ExistingChange beforeLock = findExistingChange(
                userId,
                currency,
                sourceType,
                sourceKey
        ).orElse(null);
        if (beforeLock != null) {
            return validateExisting(beforeLock, signedAmount, reasonCode);
        }

        if (createWallet) {
            ensureWallet(userId, currency, occurredAt);
        }
        WalletSnapshot current = lockWallet(userId, currency).orElse(null);
        if (current == null) {
            throw new InsufficientEnergyException(0, Math.abs(signedAmount));
        }

        ExistingChange afterLock = findExistingChange(
                userId,
                currency,
                sourceType,
                sourceKey
        ).orElse(null);
        if (afterLock != null) {
            return validateExisting(afterLock, signedAmount, reasonCode);
        }

        if (signedAmount < 0 && current.balance() < -signedAmount) {
            throw new InsufficientEnergyException(current.balance(), -signedAmount);
        }

        WalletSnapshot updated = addToWallet(
                userId,
                currency,
                signedAmount,
                occurredAt
        );
        appendLedger(
                userId,
                currency,
                signedAmount,
                reasonCode,
                sourceType,
                sourceKey,
                occurredAt,
                updated
        );
        return updated;
    }

    private WalletSnapshot validateExisting(
            ExistingChange existing,
            long signedAmount,
            String reasonCode
    ) {
        if (existing.signedAmount() != signedAmount
                || !existing.reasonCode().equals(reasonCode)) {
            throw new EconomyLedgerConflictException(
                    "Источник ledger уже использован для другой операции"
            );
        }
        return existing.walletSnapshot();
    }

    private void ensureWallet(
            String userId,
            EconomyCurrency currency,
            Instant observedAt
    ) {
        Timestamp timestamp = Timestamp.from(observedAt);
        jdbcTemplate.update("""
                INSERT INTO economy_wallet (
                    user_id,
                    currency_code,
                    balance,
                    version,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, 0, 0, ?, ?)
                ON CONFLICT (user_id, currency_code) DO NOTHING
                """, userId, currency.name(), timestamp, timestamp);
    }

    private Optional<WalletSnapshot> lockWallet(
            String userId,
            EconomyCurrency currency
    ) {
        List<WalletSnapshot> wallets = jdbcTemplate.query("""
                SELECT balance, version
                FROM economy_wallet
                WHERE user_id = ?
                  AND currency_code = ?
                FOR UPDATE
                """, (resultSet, rowNumber) -> new WalletSnapshot(
                resultSet.getLong("balance"),
                resultSet.getLong("version")
        ), userId, currency.name());
        return wallets.stream().findFirst();
    }

    private Optional<ExistingChange> findExistingChange(
            String userId,
            EconomyCurrency currency,
            String sourceType,
            String sourceKey
    ) {
        List<ExistingChange> changes = jdbcTemplate.query("""
                SELECT amount,
                       reason_code,
                       balance_after,
                       wallet_version
                FROM economy_ledger
                WHERE user_id = ?
                  AND currency_code = ?
                  AND source_type = ?
                  AND source_key = ?
                """, (resultSet, rowNumber) -> new ExistingChange(
                resultSet.getLong("amount"),
                resultSet.getString("reason_code"),
                new WalletSnapshot(
                        resultSet.getLong("balance_after"),
                        resultSet.getLong("wallet_version")
                )
        ), userId, currency.name(), sourceType, sourceKey);
        return changes.stream().findFirst();
    }

    private WalletSnapshot addToWallet(
            String userId,
            EconomyCurrency currency,
            long signedAmount,
            Instant occurredAt
    ) {
        List<WalletSnapshot> wallets = jdbcTemplate.query("""
                UPDATE economy_wallet
                SET balance = balance + ?,
                    version = version + 1,
                    updated_at = ?
                WHERE user_id = ?
                  AND currency_code = ?
                  AND balance + ? >= 0
                RETURNING balance, version
                """, (resultSet, rowNumber) -> new WalletSnapshot(
                resultSet.getLong("balance"),
                resultSet.getLong("version")
        ),
                signedAmount,
                Timestamp.from(occurredAt),
                userId,
                currency.name(),
                signedAmount
        );

        return wallets.stream()
                .findFirst()
                .orElseThrow(() -> new InsufficientEnergyException(0, Math.abs(signedAmount)));
    }

    private void appendLedger(
            String userId,
            EconomyCurrency currency,
            long signedAmount,
            String reasonCode,
            String sourceType,
            String sourceKey,
            Instant occurredAt,
            WalletSnapshot updated
    ) {
        jdbcTemplate.update("""
                INSERT INTO economy_ledger (
                    ledger_entry_id,
                    user_id,
                    currency_code,
                    amount,
                    balance_after,
                    wallet_version,
                    reason_code,
                    source_type,
                    source_key,
                    created_at
                )
                VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                userId,
                currency.name(),
                signedAmount,
                updated.balance(),
                updated.version(),
                reasonCode,
                sourceType,
                sourceKey,
                Timestamp.from(occurredAt)
        );
    }

    private record ExistingChange(
            long signedAmount,
            String reasonCode,
            WalletSnapshot walletSnapshot
    ) {
    }
}
