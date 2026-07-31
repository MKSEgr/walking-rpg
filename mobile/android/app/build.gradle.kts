import java.io.File
import java.security.KeyStore
import java.security.PrivateKey

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val repositoryRoot = rootProject.rootDir.resolve("../..").canonicalFile
val requiredSigningKeys =
    setOf(
        "storeFile",
        "storePassword",
        "keyAlias",
        "keyPassword",
    )

val requireCanonicalExternalRegularFile: (String, String) -> File = { configuredPath, description ->
    require(configuredPath.isNotBlank()) {
        "$description must not be blank"
    }

    val configuredFile = File(configuredPath)
    require(configuredFile.isAbsolute) {
        "$description must be an absolute path"
    }

    val normalizedPath = configuredFile.absoluteFile.toPath().normalize()
    val canonicalFile = configuredFile.canonicalFile
    require(normalizedPath == canonicalFile.toPath()) {
        "$description must use its canonical path without symlinks"
    }
    require(canonicalFile.isFile) {
        "$description must be an existing regular file"
    }
    require(!canonicalFile.toPath().startsWith(repositoryRoot.toPath())) {
        "$description must be outside the repository"
    }

    canonicalFile
}

val walkingRpgSigningProperties =
    providers.gradleProperty("walkingRpgSigningProperties").orNull?.let { configuredPath ->
        val propertiesFile =
            requireCanonicalExternalRegularFile(
                configuredPath,
                "walkingRpgSigningProperties",
            )
        val signingValues = linkedMapOf<String, String>()
        propertiesFile.readLines(Charsets.UTF_8).forEachIndexed { index, rawLine ->
            val trimmedLine = rawLine.trim()
            if (trimmedLine.isEmpty() || trimmedLine.startsWith("#") || trimmedLine.startsWith("!")) {
                return@forEachIndexed
            }

            require(!rawLine.endsWith("\\")) {
                "walkingRpgSigningProperties line ${index + 1} must not use continuation syntax"
            }
            val separatorIndex = rawLine.indexOf('=')
            require(separatorIndex > 0) {
                "walkingRpgSigningProperties line ${index + 1} must use key=value syntax"
            }

            val key = rawLine.substring(0, separatorIndex)
            val value = rawLine.substring(separatorIndex + 1)
            require(key in requiredSigningKeys) {
                "walkingRpgSigningProperties line ${index + 1} contains an unknown key"
            }
            require(!signingValues.containsKey(key)) {
                "walkingRpgSigningProperties contains a duplicate $key key"
            }
            signingValues[key] = value
        }

        require(signingValues.keys == requiredSigningKeys) {
            "walkingRpgSigningProperties must contain exactly: " +
                requiredSigningKeys.sorted().joinToString(", ")
        }
        requiredSigningKeys.forEach { key ->
            require(!signingValues.getValue(key).isBlank()) {
                "walkingRpgSigningProperties value for $key must not be blank"
            }
        }

        val keystoreFile =
            requireCanonicalExternalRegularFile(
                signingValues.getValue("storeFile"),
                "storeFile",
            )
        signingValues to keystoreFile
    }

android {
    namespace = "com.walkingrpg.walking_rpg_mobile"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.walkingrpg.walking_rpg_mobile"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders += mapOf(
            "appAuthRedirectScheme" to "com.walkingrpg.app",
        )
    }

    val productionSigningConfig =
        walkingRpgSigningProperties?.let { (properties, keystoreFile) ->
            signingConfigs.create("walkingRpgProduction") {
                storeFile = keystoreFile
                storePassword = properties.getValue("storePassword")
                keyAlias = properties.getValue("keyAlias")
                keyPassword = properties.getValue("keyPassword")
            }
        }

    buildTypes {
        release {
            // CI has no signing property and therefore produces an unsigned candidate.
            // Production signing is opt-in and is never replaced by the debug key.
            signingConfig = productionSigningConfig
        }
    }
}

tasks.register("verifyWalkingRpgAndroidReleaseConfiguration") {
    group = "verification"
    description = "Verifies the pinned Android SDK levels and fail-closed release signing state."

    doLast {
        check(android.compileSdk == 36) {
            "Android compileSdk must remain pinned to API 36"
        }
        check(android.defaultConfig.minSdk == 26) {
            "Android minSdk must remain pinned to API 26"
        }
        check(android.defaultConfig.targetSdk == 36) {
            "Android targetSdk must remain pinned to API 36"
        }

        val releaseSigningConfig = android.buildTypes.getByName("release").signingConfig
        if (walkingRpgSigningProperties == null) {
            check(releaseSigningConfig == null) {
                "Release builds must remain unsigned when walkingRpgSigningProperties is absent"
            }
        } else {
            val configuredReleaseSigning =
                checkNotNull(releaseSigningConfig) {
                    "Opt-in release signing must configure the release build"
                }
            check(configuredReleaseSigning.name == "walkingRpgProduction") {
                "Opt-in release signing must use only walkingRpgProduction"
            }

            val (properties, keystoreFile) = walkingRpgSigningProperties
            check(configuredReleaseSigning.storeFile?.canonicalFile == keystoreFile) {
                "walkingRpgProduction must use the reviewed external keystore"
            }
            check(configuredReleaseSigning.storePassword == properties.getValue("storePassword")) {
                "walkingRpgProduction storePassword wiring is invalid"
            }
            check(configuredReleaseSigning.keyAlias == properties.getValue("keyAlias")) {
                "walkingRpgProduction keyAlias wiring is invalid"
            }
            check(configuredReleaseSigning.keyPassword == properties.getValue("keyPassword")) {
                "walkingRpgProduction keyPassword wiring is invalid"
            }

            val keyStoreType = configuredReleaseSigning.storeType ?: KeyStore.getDefaultType()
            val keyStore = KeyStore.getInstance(keyStoreType)
            keystoreFile.inputStream().use { input ->
                keyStore.load(
                    input,
                    properties.getValue("storePassword").toCharArray(),
                )
            }
            val alias = properties.getValue("keyAlias")
            check(keyStore.isKeyEntry(alias)) {
                "walkingRpgProduction keyAlias must identify a private-key entry"
            }
            val key =
                keyStore.getKey(
                    alias,
                    properties.getValue("keyPassword").toCharArray(),
                )
            check(key is PrivateKey) {
                "walkingRpgProduction keyAlias must unlock a private key"
            }
            check(!keyStore.getCertificateChain(alias).isNullOrEmpty()) {
                "walkingRpgProduction private key must have a certificate chain"
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
