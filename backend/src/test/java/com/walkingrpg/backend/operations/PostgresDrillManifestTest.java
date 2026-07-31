package com.walkingrpg.backend.operations;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

class PostgresDrillManifestTest {

    @Test
    void shouldCanonicalizePostgresArrayCastRedistribution() {
        String source = "CHECK (decision::text = ANY (ARRAY["
                + "'ACCEPT'::character varying, "
                + "'REVIEW'::character varying, "
                + "'BLOCK'::character varying]::text[]))";
        String restored = "CHECK (decision::text = ANY (ARRAY["
                + "'ACCEPT'::character varying::text, "
                + "'REVIEW'::character varying::text, "
                + "'BLOCK'::character varying::text]))";

        assertEquals(
                PostgresDrillManifest.canonicalizeConstraintDefinition(source),
                PostgresDrillManifest.canonicalizeConstraintDefinition(restored)
        );
    }

    @Test
    void shouldPreserveConstraintValuesDuringCanonicalization() {
        String accepted = "CHECK (decision::text = ANY (ARRAY["
                + "'ACCEPT'::character varying]::text[]))";
        String blocked = "CHECK (decision::text = ANY (ARRAY["
                + "'BLOCK'::character varying::text]))";

        assertNotEquals(
                PostgresDrillManifest.canonicalizeConstraintDefinition(accepted),
                PostgresDrillManifest.canonicalizeConstraintDefinition(blocked)
        );
    }

    @Test
    void shouldLeaveUnrelatedConstraintTextUntouched() {
        String definition =
                "CHECK (balance >= 0 AND currency_code::text <> ''::text)";

        assertEquals(
                definition,
                PostgresDrillManifest.canonicalizeConstraintDefinition(
                        definition
                )
        );
    }
}
