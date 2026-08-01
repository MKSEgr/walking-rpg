package com.walkingrpg.backend.operations;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.nio.file.attribute.PosixFilePermission;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.time.Duration;
import java.time.Instant;
import java.util.Arrays;
import java.util.EnumSet;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import java.util.TreeMap;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfo;
import org.flywaydb.core.api.MigrationVersion;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.datasource.init.ScriptUtils;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;
import org.testcontainers.utility.MountableFile;
import tools.jackson.databind.ObjectMapper;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Testcontainers
class BackupRestoreDrillIntegrationTest {

    private static final String POSTGRES_IMAGE_TAG = "postgres:17.10-alpine3.24";
    private static final String POSTGRES_IMAGE_DIGEST =
            "sha256:742f40ea20b9ff2ff31db5458d127452988a2164df9e17441e191f3b72252193";
    private static final String POSTGRES_IMAGE =
            "postgres@" + POSTGRES_IMAGE_DIGEST;
    private static final DockerImageName POSTGRES_DOCKER_IMAGE =
            DockerImageName.parse(POSTGRES_IMAGE)
                    .asCompatibleSubstituteFor("postgres");
    private static final String SYNTHETIC_USERNAME = "backup_restore_drill";
    private static final String SYNTHETIC_PASSWORD = "synthetic-backup-restore-only";
    private static final String SOURCE_DATABASE = "walking_rpg_drill_source";
    private static final String RESTORE_DATABASE = "walking_rpg_drill_restore";
    private static final String ARCHIVE_FILE_NAME = "walking-rpg-synthetic.dump";
    private static final String ARCHIVE_CHECKSUM_FILE_NAME =
            "walking-rpg-synthetic.dump.sha256";
    private static final String TOC_FILE_NAME = "archive.toc";
    private static final String EVIDENCE_FILE_NAME = "evidence.json";
    private static final String EVIDENCE_CHECKSUM_FILE_NAME = "evidence.json.sha256";
    private static final String CONTAINER_ARCHIVE = "/tmp/walking-rpg-synthetic.dump";
    private static final String CONTAINER_TOC = "/tmp/archive.toc";
    private static final Pattern CHECKSUM_LINE = Pattern.compile(
            "^([0-9a-f]{64})  ([A-Za-z0-9._-]+)$"
    );
    private static final Pattern SOURCE_GIT_SHA = Pattern.compile(
            "^[0-9a-f]{40}$"
    );

    @Container
    static final PostgreSQLContainer SOURCE = postgres(SOURCE_DATABASE);

    @Container
    static final PostgreSQLContainer RESTORE = postgres(RESTORE_DATABASE);

    @Test
    void shouldRestoreVerifiedSyntheticBackupAndProduceSanitizedEvidence()
            throws Exception {
        String sourceGitSha = requiredSourceGitSha();
        requireCleanSourceTreeAssertion();
        Instant startedAt = Instant.now();
        Path outputDirectory = createOutputDirectory();
        Path archive = outputDirectory.resolve(ARCHIVE_FILE_NAME);
        Path archiveChecksum = outputDirectory.resolve(ARCHIVE_CHECKSUM_FILE_NAME);
        Path toc = outputDirectory.resolve(TOC_FILE_NAME);

        Flyway sourceFlyway = flyway(SOURCE);
        sourceFlyway.migrate();
        sourceFlyway.validate();
        String latestRepositoryVersion = latestRepositoryVersion(sourceFlyway);
        String sourceFlywayVersion = currentFlywayVersion(sourceFlyway);
        assertEquals(latestRepositoryVersion, sourceFlywayVersion);
        assertTrue(
                MigrationVersion.fromVersion(latestRepositoryVersion)
                        .compareTo(MigrationVersion.fromVersion("14")) >= 0,
                "The drill must cover Flyway V1-V14 or later"
        );

        try (Connection sourceConnection = connection(SOURCE)) {
            ScriptUtils.executeSqlScript(
                    sourceConnection,
                    new ClassPathResource("backup-restore/drill-fixture.sql")
            );
        }

        PostgresDrillManifest sourceManifest;
        try (Connection sourceConnection = connection(SOURCE)) {
            sourceManifest = PostgresDrillManifest.capture(sourceConnection);
        }
        assertTrue(sourceManifest.tables().size() >= 33);
        assertTrue(sourceManifest.applicationTableCount() >= 32);
        assertEquals(
                sourceManifest.applicationTableCount(),
                sourceManifest.fixtureCoveredApplicationTableCount()
        );
        assertTrue(
                sourceManifest.emptyApplicationTables().isEmpty(),
                () -> "Synthetic fixture does not cover "
                        + sourceManifest.emptyApplicationTables()
        );
        assertTrue(sourceManifest.sequences().size() >= 3);

        createArchive(archive, toc);
        String archiveSha256 = sha256(archive);
        writeChecksum(archiveChecksum, archiveSha256, ARCHIVE_FILE_NAME);
        assertTrue(Files.size(archive) > 0);
        assertTrue(Files.size(toc) > 0);

        assertTrue(targetDatabaseIsEmpty());
        assertThrows(
                IllegalStateException.class,
                () -> requireExpectedChecksum(archive, "0".repeat(64))
        );
        assertTrue(
                targetDatabaseIsEmpty(),
                "A checksum failure must happen before target mutation"
        );

        String expectedArchiveSha256 = readChecksum(
                archiveChecksum,
                ARCHIVE_FILE_NAME
        );
        requireExpectedChecksum(archive, expectedArchiveSha256);
        restoreArchive(archive);

        Flyway restoredFlyway = flyway(RESTORE);
        restoredFlyway.validate();
        String restoredFlywayVersion = currentFlywayVersion(restoredFlyway);
        assertEquals(latestRepositoryVersion, restoredFlywayVersion);

        PostgresDrillManifest restoredManifest;
        try (Connection restoredConnection = connection(RESTORE)) {
            restoredManifest = PostgresDrillManifest.capture(restoredConnection);
            verifyCriticalSyntheticData(restoredConnection);
        }
        assertManifestsMatch(sourceManifest, restoredManifest);

        Instant completedAt = Instant.now();
        writeEvidence(
                outputDirectory,
                startedAt,
                completedAt,
                archive,
                archiveSha256,
                toc,
                latestRepositoryVersion,
                sourceFlywayVersion,
                restoredFlywayVersion,
                sourceManifest,
                restoredManifest,
                sourceGitSha
        );

        assertTrue(Files.isRegularFile(outputDirectory.resolve(EVIDENCE_FILE_NAME)));
        assertTrue(Files.isRegularFile(
                outputDirectory.resolve(EVIDENCE_CHECKSUM_FILE_NAME)
        ));
        System.out.println("Synthetic backup/restore evidence: " + outputDirectory);
    }

    private static PostgreSQLContainer postgres(String databaseName) {
        return new PostgreSQLContainer(POSTGRES_DOCKER_IMAGE)
                .withDatabaseName(databaseName)
                .withUsername(SYNTHETIC_USERNAME)
                .withPassword(SYNTHETIC_PASSWORD)
                .withEnv("PGPASSWORD", SYNTHETIC_PASSWORD)
                .withStartupTimeout(Duration.ofMinutes(2));
    }

    private static Flyway flyway(PostgreSQLContainer postgres) {
        return Flyway.configure()
                .dataSource(
                        postgres.getJdbcUrl(),
                        postgres.getUsername(),
                        postgres.getPassword()
                )
                .load();
    }

    private static Connection connection(PostgreSQLContainer postgres)
            throws Exception {
        return DriverManager.getConnection(
                postgres.getJdbcUrl(),
                postgres.getUsername(),
                postgres.getPassword()
        );
    }

    private static Path createOutputDirectory() throws IOException {
        String configured = System.getProperty(
                "walkingRpg.backupRestoreEvidenceDirectory"
        );
        Path outputDirectory = configured == null || configured.isBlank()
                ? Path.of(
                        "target",
                        "backup-restore-drill",
                        UUID.randomUUID().toString()
                )
                : Path.of(configured);
        outputDirectory = outputDirectory.toAbsolutePath().normalize();
        if (Files.exists(outputDirectory)) {
            throw new IllegalStateException(
                    "Backup/restore output directory must not already exist: "
                            + outputDirectory
            );
        }
        Files.createDirectories(outputDirectory);
        setDirectoryPermissions(outputDirectory);
        return outputDirectory;
    }

    private static void createArchive(Path archive, Path toc)
            throws IOException, InterruptedException {
        requireSuccess(
                SOURCE,
                "pg_dump",
                "pg_dump",
                "--host=127.0.0.1",
                "--port=5432",
                "--username=" + SYNTHETIC_USERNAME,
                "--dbname=" + SOURCE_DATABASE,
                "--no-password",
                "--format=custom",
                "--no-owner",
                "--no-privileges",
                "--no-tablespaces",
                "--lock-wait-timeout=30s",
                "--file=" + CONTAINER_ARCHIVE
        );
        requireSuccess(
                SOURCE,
                "pg_restore --list",
                "pg_restore",
                "--list",
                "--file=" + CONTAINER_TOC,
                CONTAINER_ARCHIVE
        );
        SOURCE.copyFileFromContainer(CONTAINER_ARCHIVE, archive.toString());
        SOURCE.copyFileFromContainer(CONTAINER_TOC, toc.toString());
        setPrivateFilePermissions(archive);
        setPrivateFilePermissions(toc);
    }

    private static void restoreArchive(Path archive)
            throws IOException, InterruptedException {
        RESTORE.copyFileToContainer(
                MountableFile.forHostPath(archive.toString()),
                CONTAINER_ARCHIVE
        );
        requireSuccess(
                RESTORE,
                "pg_restore",
                "pg_restore",
                "--host=127.0.0.1",
                "--port=5432",
                "--username=" + SYNTHETIC_USERNAME,
                "--dbname=" + RESTORE_DATABASE,
                "--no-password",
                "--single-transaction",
                "--exit-on-error",
                "--no-owner",
                "--no-privileges",
                "--no-tablespaces",
                CONTAINER_ARCHIVE
        );
    }

    private static org.testcontainers.containers.Container.ExecResult requireSuccess(
            PostgreSQLContainer postgres,
            String operation,
            String... command
    ) throws IOException, InterruptedException {
        org.testcontainers.containers.Container.ExecResult result =
                postgres.execInContainer(command);
        if (result.getExitCode() != 0) {
            throw new IllegalStateException(
                    operation
                            + " failed with exit code "
                            + result.getExitCode()
                            + ": "
                            + sanitizedDiagnostic(result)
            );
        }
        return result;
    }

    private static String sanitizedDiagnostic(
            org.testcontainers.containers.Container.ExecResult result
    ) {
        String diagnostic = result.getStderr() + "\n" + result.getStdout();
        diagnostic = diagnostic.replace(SYNTHETIC_PASSWORD, "<redacted>");
        return diagnostic.length() <= 2_000
                ? diagnostic
                : diagnostic.substring(0, 2_000);
    }

    private static boolean targetDatabaseIsEmpty() throws Exception {
        try (Connection connection = connection(RESTORE);
                Statement statement = connection.createStatement();
                ResultSet result = statement.executeQuery("""
                        SELECT count(*)
                        FROM information_schema.tables
                        WHERE table_schema = 'public'
                          AND table_type = 'BASE TABLE'
                        """)) {
            result.next();
            return result.getLong(1) == 0;
        }
    }

    private static void requireExpectedChecksum(Path archive, String expected)
            throws IOException {
        if (!expected.matches("[0-9a-f]{64}")) {
            throw new IllegalStateException("Expected SHA-256 is malformed");
        }
        byte[] expectedBytes = HexFormat.of().parseHex(expected);
        byte[] actualBytes = HexFormat.of().parseHex(sha256(archive));
        if (!MessageDigest.isEqual(expectedBytes, actualBytes)) {
            throw new IllegalStateException(
                    "Archive SHA-256 does not match the trusted checksum"
            );
        }
    }

    private static String readChecksum(Path checksumFile, String expectedFileName)
            throws IOException {
        String line = Files.readString(checksumFile, StandardCharsets.US_ASCII)
                .strip();
        Matcher matcher = CHECKSUM_LINE.matcher(line);
        if (!matcher.matches() || !matcher.group(2).equals(expectedFileName)) {
            throw new IllegalStateException(
                    "Malformed checksum file for " + expectedFileName
            );
        }
        return matcher.group(1);
    }

    private static void writeChecksum(
            Path checksumFile,
            String checksum,
            String fileName
    ) throws IOException {
        Files.writeString(
                checksumFile,
                checksum + "  " + fileName + "\n",
                StandardCharsets.US_ASCII,
                StandardOpenOption.CREATE_NEW,
                StandardOpenOption.WRITE
        );
        setPrivateFilePermissions(checksumFile);
    }

    private static String sha256(Path path) throws IOException {
        MessageDigest digest = newDigest();
        try (InputStream input = Files.newInputStream(path)) {
            byte[] buffer = new byte[64 * 1024];
            int read;
            while ((read = input.read(buffer)) >= 0) {
                digest.update(buffer, 0, read);
            }
        }
        return HexFormat.of().formatHex(digest.digest());
    }

    private static MessageDigest newDigest() {
        try {
            return MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is required", exception);
        }
    }

    private static String latestRepositoryVersion(Flyway flyway) {
        return Arrays.stream(flyway.info().all())
                .map(MigrationInfo::getVersion)
                .filter(Objects::nonNull)
                .max(MigrationVersion::compareTo)
                .orElseThrow(() -> new IllegalStateException(
                        "No versioned Flyway migration was resolved"
                ))
                .getVersion();
    }

    private static String currentFlywayVersion(Flyway flyway) {
        MigrationInfo current = flyway.info().current();
        assertNotNull(current, "Flyway current migration is required");
        assertNotNull(current.getVersion(), "Flyway current version is required");
        return current.getVersion().getVersion();
    }

    private static void verifyCriticalSyntheticData(Connection connection)
            throws Exception {
        assertEquals(10, scalarLong(connection, """
                SELECT balance
                FROM economy_wallet
                WHERE user_id = 'backup-drill-user'
                  AND currency_code = 'ENERGY'
                """));
        assertEquals(2, scalarLong(connection, """
                SELECT quantity
                FROM inventory_stack
                WHERE user_id = 'backup-drill-user'
                  AND item_id = 'lumen-shard'
                """));
        assertEquals(8, scalarLong(connection, """
                SELECT count(*)
                FROM first_journey_milestone
                WHERE user_id = 'backup-drill-user'
                """));
        assertTrue(scalarBoolean(connection, """
                SELECT acknowledged_at IS NOT NULL
                FROM processed_event_resolution
                WHERE receipt_id = '30000000-0000-0000-0000-000000000001'
                """));
        assertEquals(1, scalarLong(connection, """
                SELECT count(*)
                FROM unique_inventory_item
                WHERE user_id = 'backup-drill-user'
                  AND item_id = 'resonance-compass'
                """));
        assertEquals(2, scalarLong(connection, """
                SELECT count(*)
                FROM processed_crafting_ingredient
                WHERE user_id = 'backup-drill-user'
                  AND recipe_id = 'resonance-compass-v1'
                """));
        assertEquals(1, scalarLong(connection, """
                SELECT count(*)
                FROM equipment_slot_state
                WHERE user_id = 'backup-drill-user'
                  AND slot_id = 'NAVIGATION'
                  AND item_instance_id =
                      '70000000-0000-0000-0000-000000000001'
                """));
        assertEquals(1, scalarLong(connection, """
                SELECT count(*)
                FROM processed_equipment_command
                WHERE user_id = 'backup-drill-user'
                  AND slot_id = 'NAVIGATION'
                  AND action = 'EQUIP'
                  AND item_id = 'resonance-compass'
                """));
        assertFalse(scalarBoolean(connection, """
                SELECT (config_json ->> 'sandboxPaymentsEnabled')::boolean
                FROM remote_config_snapshot
                WHERE is_active
                """));
        assertFalse(scalarBoolean(connection, """
                SELECT (config_json ->> 'backgroundHealthSyncEnabled')::boolean
                FROM remote_config_snapshot
                WHERE is_active
                """));
    }

    private static long scalarLong(Connection connection, String query)
            throws Exception {
        try (Statement statement = connection.createStatement();
                ResultSet result = statement.executeQuery(query)) {
            result.next();
            return result.getLong(1);
        }
    }

    private static boolean scalarBoolean(Connection connection, String query)
            throws Exception {
        try (Statement statement = connection.createStatement();
                ResultSet result = statement.executeQuery(query)) {
            result.next();
            return result.getBoolean(1);
        }
    }

    private static void assertManifestsMatch(
            PostgresDrillManifest source,
            PostgresDrillManifest restored
    ) {
        assertEquals(
                source.schemaSections(),
                restored.schemaSections(),
                "Schema section digests must match after restore"
        );
        assertEquals(source.schemaSha256(), restored.schemaSha256());
        assertEquals(source.dataSha256(), restored.dataSha256());
        assertEquals(source.sequenceSha256(), restored.sequenceSha256());
        assertEquals(source.tables(), restored.tables());
        assertEquals(source.sequences(), restored.sequences());
    }

    private static void writeEvidence(
            Path outputDirectory,
            Instant startedAt,
            Instant completedAt,
            Path archive,
            String archiveSha256,
            Path toc,
            String latestRepositoryVersion,
            String sourceFlywayVersion,
            String restoredFlywayVersion,
            PostgresDrillManifest sourceManifest,
            PostgresDrillManifest restoredManifest,
            String sourceGitSha
    ) throws Exception {
        Map<String, Object> evidence = new LinkedHashMap<>();
        evidence.put(
                "schemaVersion",
                "walking-rpg-backup-restore-evidence-v1"
        );
        evidence.put("scope", "SYNTHETIC_CI");
        evidence.put("productionValidated", false);
        evidence.put("actualProductionDrillRequired", true);
        evidence.put("sourceGitSha", sourceGitSha);
        evidence.put("sourceTreeClean", true);
        evidence.put("startedAtUtc", startedAt.toString());
        evidence.put("completedAtUtc", completedAt.toString());
        evidence.put(
                "durationMillis",
                Duration.between(startedAt, completedAt).toMillis()
        );

        Map<String, Object> postgres = new LinkedHashMap<>();
        postgres.put("image", POSTGRES_IMAGE);
        postgres.put("imageTag", POSTGRES_IMAGE_TAG);
        postgres.put("imageDigest", POSTGRES_IMAGE_DIGEST);
        postgres.put("sourceServerVersion", serverVersion(SOURCE));
        postgres.put("restoreServerVersion", serverVersion(RESTORE));
        postgres.put(
                "pgDumpVersion",
                requireSuccess(SOURCE, "pg_dump --version", "pg_dump", "--version")
                        .getStdout()
                        .strip()
        );
        postgres.put(
                "pgRestoreVersion",
                requireSuccess(
                        RESTORE,
                        "pg_restore --version",
                        "pg_restore",
                        "--version"
                ).getStdout().strip()
        );
        evidence.put("postgres", postgres);

        Map<String, Object> archiveEvidence = new LinkedHashMap<>();
        archiveEvidence.put("format", "custom");
        archiveEvidence.put("file", ARCHIVE_FILE_NAME);
        archiveEvidence.put("bytes", Files.size(archive));
        archiveEvidence.put("sha256", archiveSha256);
        archiveEvidence.put("sha256File", ARCHIVE_CHECKSUM_FILE_NAME);
        archiveEvidence.put("tocFile", TOC_FILE_NAME);
        archiveEvidence.put("tocSha256", sha256(toc));
        archiveEvidence.put("checksumVerifiedBeforeRestore", true);
        evidence.put("archive", archiveEvidence);

        Map<String, Object> restore = new LinkedHashMap<>();
        restore.put("targetInitiallyEmpty", true);
        restore.put("completed", true);
        restore.put(
                "flags",
                Arrays.asList(
                        "--single-transaction",
                        "--exit-on-error",
                        "--no-owner",
                        "--no-privileges",
                        "--no-tablespaces"
                )
        );
        evidence.put("restore", restore);

        Map<String, Object> flyway = new LinkedHashMap<>();
        flyway.put("latestRepositoryVersion", latestRepositoryVersion);
        flyway.put("sourceVersion", sourceFlywayVersion);
        flyway.put("restoredVersion", restoredFlywayVersion);
        flyway.put("validationSuccessful", true);
        evidence.put("flyway", flyway);

        Map<String, Object> manifests = new LinkedHashMap<>();
        manifests.put("tableCount", sourceManifest.tables().size());
        manifests.put(
                "applicationTableCount",
                sourceManifest.applicationTableCount()
        );
        manifests.put(
                "fixtureCoveredApplicationTableCount",
                sourceManifest.fixtureCoveredApplicationTableCount()
        );
        manifests.put("sequenceCount", sourceManifest.sequences().size());
        manifests.put(
                "tableRowCounts",
                tableRowCounts(sourceManifest)
        );
        manifests.put(
                "schema",
                matchingDigestEvidence(
                        sourceManifest.schemaSha256(),
                        restoredManifest.schemaSha256()
                )
        );
        manifests.put(
                "data",
                matchingDigestEvidence(
                        sourceManifest.dataSha256(),
                        restoredManifest.dataSha256()
                )
        );
        manifests.put(
                "sequences",
                matchingDigestEvidence(
                        sourceManifest.sequenceSha256(),
                        restoredManifest.sequenceSha256()
                )
        );
        evidence.put("manifests", manifests);

        Path evidenceFile = outputDirectory.resolve(EVIDENCE_FILE_NAME);
        new ObjectMapper()
                .writerWithDefaultPrettyPrinter()
                .writeValue(evidenceFile.toFile(), evidence);
        setPrivateFilePermissions(evidenceFile);
        writeChecksum(
                outputDirectory.resolve(EVIDENCE_CHECKSUM_FILE_NAME),
                sha256(evidenceFile),
                EVIDENCE_FILE_NAME
        );
    }

    private static String requiredSourceGitSha() {
        String sourceGitSha = System.getProperty("walkingRpg.sourceGitSha");
        if (sourceGitSha == null
                || !SOURCE_GIT_SHA.matcher(sourceGitSha).matches()) {
            throw new IllegalStateException(
                    "walkingRpg.sourceGitSha must be 40 lowercase hex"
            );
        }
        return sourceGitSha;
    }

    private static void requireCleanSourceTreeAssertion() {
        if (!"true".equals(
                System.getProperty("walkingRpg.sourceTreeClean")
        )) {
            throw new IllegalStateException(
                    "walkingRpg.sourceTreeClean must be asserted by the runner"
            );
        }
    }

    private static Map<String, Long> tableRowCounts(
            PostgresDrillManifest manifest
    ) {
        Map<String, Long> counts = new TreeMap<>();
        manifest.tables().forEach(
                (tableName, digest) -> counts.put(tableName, digest.rowCount())
        );
        return counts;
    }

    private static Map<String, Object> matchingDigestEvidence(
            String sourceSha256,
            String restoredSha256
    ) {
        Map<String, Object> evidence = new LinkedHashMap<>();
        evidence.put("sourceSha256", sourceSha256);
        evidence.put("restoredSha256", restoredSha256);
        evidence.put("matched", MessageDigest.isEqual(
                HexFormat.of().parseHex(sourceSha256),
                HexFormat.of().parseHex(restoredSha256)
        ));
        return evidence;
    }

    private static String serverVersion(PostgreSQLContainer postgres)
            throws Exception {
        try (Connection connection = connection(postgres);
                Statement statement = connection.createStatement();
                ResultSet result = statement.executeQuery("SHOW server_version")) {
            result.next();
            return result.getString(1);
        }
    }

    private static void setDirectoryPermissions(Path directory) throws IOException {
        try {
            Files.setPosixFilePermissions(
                    directory,
                    EnumSet.of(
                            PosixFilePermission.OWNER_READ,
                            PosixFilePermission.OWNER_WRITE,
                            PosixFilePermission.OWNER_EXECUTE
                    )
            );
        } catch (UnsupportedOperationException ignored) {
            // The drill runs on Linux in CI; non-POSIX local filesystems are allowed.
        }
    }

    private static void setPrivateFilePermissions(Path file) throws IOException {
        try {
            Files.setPosixFilePermissions(
                    file,
                    EnumSet.of(
                            PosixFilePermission.OWNER_READ,
                            PosixFilePermission.OWNER_WRITE
                    )
            );
        } catch (UnsupportedOperationException ignored) {
            // The drill runs on Linux in CI; non-POSIX local filesystems are allowed.
        }
    }
}
