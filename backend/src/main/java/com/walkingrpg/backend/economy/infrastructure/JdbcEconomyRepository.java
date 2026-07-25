package com.walkingrpg.backend.economy.infrastructure;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

import com.walkingrpg.backend.economy.domain.EconomyCredit;
import com.walkingrpg.backend.economy.domain.EconomyCurrency;
import com.walkingrpg.backend.economy.domain.EconomyLedgerConflictException;
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
        return lockWallet(userId, currency);
    }

    @Override
    public WalletSnapshot applyCredit(EconomyCredit credit) {
        currentBalance(credit.userId(), credit.currency(), credit.occurredAt());

        ExistingCredit existing = findExistingCredit(credit).orElse(null);
        if (existing != null) {
            if (existing.amount() != credit.amount()
                    || !existing.reasonCode().equals(credit.reasonCode())) {
                throw new EconomyLedgerConflictException(
                        "Источник ledger уже использован для другого начисления"
                );
            }
            return existing.walletSnapshot();
        }

        WalletSnapshot updated = addToWallet(credit);
        appendLedger(credit, updated);
        return updated;
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

    private WalletSnapshot lockWallet(String userId, EconomyCurrency currency) {
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

        return wallets.stream()
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("Кошелёк не был создан"));
    }

    private Optional<ExistingCredit> findExistingCredit(EconomyCredit credit) {
        List<ExistingCredit> credits = jdbcTemplate.query("""
                SELECT amount,
                       reason_code,
                       balance_after,
                       wallet_version
                FROM economy_ledger
                WHERE user_id = ?
                  AND currency_code = ?
                  AND source_type = ?
                  AND source_key = ?
                """, (resultSet, rowNumber) -> new ExistingCredit(
                resultSet.getLong("amount"),
                resultSet.getString("reason_code"),
                new WalletSnapshot(
                        resultSet.getLong("balance_after"),
                        resultSet.getLong("wallet_version")
                )
        ),
                credit.userId(),
                credit.currency().name(),
                credit.sourceType(),
                credit.sourceKey()
        );
        return credits.stream().findFirst();
    }

    private WalletSnapshot addToWallet(EconomyCredit credit) {
        List<WalletSnapshot> wallets = jdbcTemplate.query("""
                UPDATE economy_wallet
                SET balance = balance + ?,
                    version = version + 1,
                    updated_at = ?
                WHERE user_id = ?
                  AND currency_code = ?
                RETURNING balance, version
                """, (resultSet, rowNumber) -> new WalletSnapshot(
                resultSet.getLong("balance"),
                resultSet.getLong("version")
        ),
                credit.amount(),
                Timestamp.from(credit.occurredAt()),
                credit.userId(),
                credit.currency().name()
        );

        return wallets.stream()
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("Не удалось обновить кошелёк"));
    }

    private void appendLedger(EconomyCredit credit, WalletSnapshot updated) {
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
                credit.userId(),
                credit.currency().name(),
                credit.amount(),
                updated.balance(),
                updated.version(),
                credit.reasonCode(),
                credit.sourceType(),
                credit.sourceKey(),
                Timestamp.from(credit.occurredAt())
        );
    }

    private record ExistingCredit(
            long amount,
            String reasonCode,
            WalletSnapshot walletSnapshot
    ) {
    }
}
