package com.walkingrpg.backend.operations;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.SortedMap;
import java.util.TreeMap;

final class PostgresDrillManifest {

    private static final List<String> SCHEMA_QUERIES = List.of(
            """
            SELECT pg_encoding_to_char(database_entry.encoding) AS encoding,
                   database_entry.datcollate,
                   database_entry.datctype
            FROM pg_database database_entry
            WHERE database_entry.datname = current_database()
            """,
            """
            SELECT namespace.nspname,
                   relation.relkind,
                   relation.relname,
                   attribute.attnum,
                   attribute.attname,
                   format_type(attribute.atttypid, attribute.atttypmod) AS data_type,
                   attribute.attnotnull,
                   attribute.attidentity,
                   attribute.attgenerated,
                   COALESCE(
                       pg_get_expr(default_value.adbin, default_value.adrelid),
                       ''
                   ) AS default_expression
            FROM pg_class relation
            JOIN pg_namespace namespace
              ON namespace.oid = relation.relnamespace
            JOIN pg_attribute attribute
              ON attribute.attrelid = relation.oid
            LEFT JOIN pg_attrdef default_value
              ON default_value.adrelid = relation.oid
             AND default_value.adnum = attribute.attnum
            WHERE namespace.nspname = 'public'
              AND relation.relkind IN ('r', 'p', 'S', 'v', 'm', 'f')
              AND attribute.attnum > 0
              AND NOT attribute.attisdropped
            ORDER BY namespace.nspname,
                     relation.relkind,
                     relation.relname,
                     attribute.attnum
            """,
            """
            SELECT relation.relname,
                   constraint_definition.conname,
                   constraint_definition.contype,
                   constraint_definition.condeferrable,
                   constraint_definition.condeferred,
                   constraint_definition.convalidated,
                   pg_get_constraintdef(constraint_definition.oid, true)
            FROM pg_constraint constraint_definition
            JOIN pg_class relation
              ON relation.oid = constraint_definition.conrelid
            JOIN pg_namespace namespace
              ON namespace.oid = relation.relnamespace
            WHERE namespace.nspname = 'public'
            ORDER BY relation.relname, constraint_definition.conname
            """,
            """
            SELECT tablename, indexname, indexdef
            FROM pg_indexes
            WHERE schemaname = 'public'
            ORDER BY tablename, indexname
            """,
            """
            SELECT routine.oid::regprocedure::text AS signature,
                   routine.prokind,
                   routine.provolatile,
                   routine.prosecdef,
                   pg_get_functiondef(routine.oid)
            FROM pg_proc routine
            JOIN pg_namespace namespace
              ON namespace.oid = routine.pronamespace
            WHERE namespace.nspname = 'public'
            ORDER BY signature
            """,
            """
            SELECT relation.relname,
                   trigger_definition.tgname,
                   pg_get_triggerdef(trigger_definition.oid, true)
            FROM pg_trigger trigger_definition
            JOIN pg_class relation
              ON relation.oid = trigger_definition.tgrelid
            JOIN pg_namespace namespace
              ON namespace.oid = relation.relnamespace
            WHERE namespace.nspname = 'public'
              AND NOT trigger_definition.tgisinternal
            ORDER BY relation.relname, trigger_definition.tgname
            """
    );

    private final String schemaSha256;
    private final String dataSha256;
    private final String sequenceSha256;
    private final SortedMap<String, TableDigest> tables;
    private final SortedMap<String, String> sequences;

    private PostgresDrillManifest(
            String schemaSha256,
            String dataSha256,
            String sequenceSha256,
            SortedMap<String, TableDigest> tables,
            SortedMap<String, String> sequences
    ) {
        this.schemaSha256 = schemaSha256;
        this.dataSha256 = dataSha256;
        this.sequenceSha256 = sequenceSha256;
        this.tables = Collections.unmodifiableSortedMap(new TreeMap<>(tables));
        this.sequences = Collections.unmodifiableSortedMap(new TreeMap<>(sequences));
    }

    static PostgresDrillManifest capture(Connection connection) throws SQLException {
        try (Statement statement = connection.createStatement()) {
            statement.execute("SET TIME ZONE 'UTC'");
        }

        SortedMap<String, TableDigest> tables = captureTables(connection);
        SortedMap<String, String> sequences = captureSequences(connection);

        return new PostgresDrillManifest(
                captureSchemaSha256(connection),
                digestTableSummary(tables),
                digestSequenceSummary(sequences),
                tables,
                sequences
        );
    }

    String schemaSha256() {
        return schemaSha256;
    }

    String dataSha256() {
        return dataSha256;
    }

    String sequenceSha256() {
        return sequenceSha256;
    }

    SortedMap<String, TableDigest> tables() {
        return tables;
    }

    SortedMap<String, String> sequences() {
        return sequences;
    }

    int applicationTableCount() {
        return Math.toIntExact(tables.keySet().stream()
                .filter(table -> !table.equals("flyway_schema_history"))
                .count());
    }

    int fixtureCoveredApplicationTableCount() {
        return Math.toIntExact(tables.entrySet().stream()
                .filter(entry -> !entry.getKey().equals("flyway_schema_history"))
                .filter(entry -> entry.getValue().rowCount() > 0)
                .count());
    }

    List<String> emptyApplicationTables() {
        return tables.entrySet().stream()
                .filter(entry -> !entry.getKey().equals("flyway_schema_history"))
                .filter(entry -> entry.getValue().rowCount() == 0)
                .map(Map.Entry::getKey)
                .toList();
    }

    private static String captureSchemaSha256(Connection connection) throws SQLException {
        MessageDigest digest = newDigest();
        for (int index = 0; index < SCHEMA_QUERIES.size(); index++) {
            update(digest, "schema-query-" + index);
            try (Statement statement = connection.createStatement();
                    ResultSet result = statement.executeQuery(SCHEMA_QUERIES.get(index))) {
                appendResultSet(digest, result);
            }
        }
        return HexFormat.of().formatHex(digest.digest());
    }

    private static SortedMap<String, TableDigest> captureTables(Connection connection)
            throws SQLException {
        List<String> tableNames = new ArrayList<>();
        try (Statement statement = connection.createStatement();
                ResultSet result = statement.executeQuery("""
                        SELECT table_name
                        FROM information_schema.tables
                        WHERE table_schema = 'public'
                          AND table_type = 'BASE TABLE'
                        ORDER BY table_name
                        """)) {
            while (result.next()) {
                tableNames.add(result.getString(1));
            }
        }

        SortedMap<String, TableDigest> tables = new TreeMap<>();
        for (String tableName : tableNames) {
            List<String> primaryKeyColumns = primaryKeyColumns(connection, tableName);
            if (primaryKeyColumns.isEmpty()) {
                throw new IllegalStateException(
                        "Backup drill requires a deterministic primary key for public."
                                + tableName
                );
            }

            String orderBy = primaryKeyColumns.stream()
                    .map(PostgresDrillManifest::quoteIdentifier)
                    .map(column -> "table_row." + column)
                    .reduce((left, right) -> left + ", " + right)
                    .orElseThrow();
            String query = "SELECT to_jsonb(table_row)::text"
                    + " FROM public." + quoteIdentifier(tableName) + " table_row"
                    + " ORDER BY " + orderBy;

            MessageDigest digest = newDigest();
            long rowCount = 0;
            try (Statement statement = connection.createStatement();
                    ResultSet result = statement.executeQuery(query)) {
                while (result.next()) {
                    update(digest, result.getString(1));
                    rowCount++;
                }
            }
            tables.put(
                    tableName,
                    new TableDigest(rowCount, HexFormat.of().formatHex(digest.digest()))
            );
        }
        return tables;
    }

    private static List<String> primaryKeyColumns(Connection connection, String tableName)
            throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
                SELECT attribute.attname
                FROM pg_index index_definition
                JOIN pg_class relation
                  ON relation.oid = index_definition.indrelid
                JOIN pg_namespace namespace
                  ON namespace.oid = relation.relnamespace
                JOIN unnest(index_definition.indkey)
                     WITH ORDINALITY AS key_column(attnum, ordinal_position)
                  ON true
                JOIN pg_attribute attribute
                  ON attribute.attrelid = relation.oid
                 AND attribute.attnum = key_column.attnum
                WHERE namespace.nspname = 'public'
                  AND relation.relname = ?
                  AND index_definition.indisprimary
                ORDER BY key_column.ordinal_position
                """)) {
            statement.setString(1, tableName);
            try (ResultSet result = statement.executeQuery()) {
                List<String> columns = new ArrayList<>();
                while (result.next()) {
                    columns.add(result.getString(1));
                }
                return columns;
            }
        }
    }

    private static SortedMap<String, String> captureSequences(Connection connection)
            throws SQLException {
        SortedMap<String, String> sequences = new TreeMap<>();
        try (Statement statement = connection.createStatement();
                ResultSet result = statement.executeQuery("""
                        SELECT sequencename,
                               data_type,
                               start_value,
                               min_value,
                               max_value,
                               increment_by,
                               cycle,
                               cache_size,
                               last_value
                        FROM pg_sequences
                        WHERE schemaname = 'public'
                        ORDER BY sequencename
                        """)) {
            while (result.next()) {
                String sequenceName = result.getString("sequencename");
                String metadata = String.join(
                        "|",
                        nullableValue(result, "data_type"),
                        nullableValue(result, "start_value"),
                        nullableValue(result, "min_value"),
                        nullableValue(result, "max_value"),
                        nullableValue(result, "increment_by"),
                        nullableValue(result, "cycle"),
                        nullableValue(result, "cache_size"),
                        nullableValue(result, "last_value")
                );
                boolean isCalled;
                try (Statement stateStatement = connection.createStatement();
                        ResultSet state = stateStatement.executeQuery(
                                "SELECT is_called FROM public."
                                        + quoteIdentifier(sequenceName)
                        )) {
                    state.next();
                    isCalled = state.getBoolean(1);
                }
                sequences.put(sequenceName, metadata + "|" + isCalled);
            }
        }
        return sequences;
    }

    private static String nullableValue(ResultSet result, String column)
            throws SQLException {
        String value = result.getString(column);
        return value == null ? "<NULL>" : value;
    }

    private static String digestTableSummary(SortedMap<String, TableDigest> tables) {
        MessageDigest digest = newDigest();
        tables.forEach((tableName, tableDigest) -> {
            update(digest, tableName);
            update(digest, Long.toString(tableDigest.rowCount()));
            update(digest, tableDigest.sha256());
        });
        return HexFormat.of().formatHex(digest.digest());
    }

    private static String digestSequenceSummary(SortedMap<String, String> sequences) {
        MessageDigest digest = newDigest();
        sequences.forEach((sequenceName, state) -> {
            update(digest, sequenceName);
            update(digest, state);
        });
        return HexFormat.of().formatHex(digest.digest());
    }

    private static void appendResultSet(MessageDigest digest, ResultSet result)
            throws SQLException {
        ResultSetMetaData metadata = result.getMetaData();
        while (result.next()) {
            for (int column = 1; column <= metadata.getColumnCount(); column++) {
                String value = result.getString(column);
                update(digest, value == null ? "<NULL>" : value);
            }
            update(digest, "<ROW>");
        }
    }

    private static MessageDigest newDigest() {
        try {
            return MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is required", exception);
        }
    }

    private static void update(MessageDigest digest, String value) {
        byte[] bytes = value.getBytes(StandardCharsets.UTF_8);
        digest.update(Integer.toString(bytes.length).getBytes(StandardCharsets.US_ASCII));
        digest.update((byte) ':');
        digest.update(bytes);
        digest.update((byte) '\n');
    }

    private static String quoteIdentifier(String identifier) {
        return '"' + identifier.replace("\"", "\"\"") + '"';
    }

    record TableDigest(long rowCount, String sha256) {
    }
}
