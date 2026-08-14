import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

import yaml


SCRIPT = Path(__file__).with_name("verify_backend_base_pins.py")
SPEC = importlib.util.spec_from_file_location("verify_backend_base_pins", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)

JDK = MODULE.APPROVED_STAGES[0].image
JRE = MODULE.APPROVED_STAGES[1].image
VALID = f"FROM {JDK} AS build\nRUN true\nFROM {JRE}\nRUN true\n"
PUBLISH_WORKFLOW = (
    SCRIPT.parents[2]
    / ".github"
    / "workflows"
    / "publish-backend-release-candidate.yml"
)


class VerifyBackendBasePinsTest(unittest.TestCase):

    def validate(self, source: str) -> list[str]:
        return MODULE.validate_dockerfile_source(source, Path("Dockerfile"))

    def test_accepts_reviewed_tag_and_index_digest_pins(self):
        self.assertEqual([], self.validate(VALID))

    def test_publisher_requires_read_only_root_owned_provenance_files(self):
        workflow = yaml.safe_load(PUBLISH_WORKFLOW.read_text(encoding="utf-8"))
        steps = workflow["jobs"]["publish"]["steps"]
        verification = next(
            step
            for step in steps
            if step.get("name") == "Verify published image provenance contract"
        )["run"]

        for filename in ("source-git-sha", "source-git-tree"):
            with self.subTest(filename=filename):
                expected = (
                    'test "$(docker run --rm --entrypoint /usr/bin/stat '
                    '"$image_reference" \\\n'
                    "  -c '%u:%g:%a' /usr/local/share/walking-rpg/"
                    f'{filename})" = \\\n'
                    "  '0:0:444'"
                )
                self.assertIn(expected, verification)

    def test_rejects_moving_tag_only_references(self):
        for image in (
            "eclipse-temurin:21-jdk-jammy",
            "eclipse-temurin:21-jre-jammy",
        ):
            with self.subTest(image=image):
                source = VALID.replace(JDK if "jdk" in image else JRE, image)
                self.assertTrue(self.validate(source))

    def test_rejects_digest_only_references(self):
        source = VALID.replace(
            JDK,
            "eclipse-temurin@sha256:" + "1" * 64,
        )
        self.assertTrue(self.validate(source))

    def test_rejects_short_uppercase_and_malformed_digests(self):
        invalid = (
            "eclipse-temurin:21-jdk-jammy@sha256:" + "1" * 63,
            "eclipse-temurin:21-jdk-jammy@sha256:" + "A" * 64,
            "eclipse-temurin:21-jdk-jammy@sha512:" + "1" * 64,
        )
        for image in invalid:
            with self.subTest(image=image):
                self.assertTrue(self.validate(VALID.replace(JDK, image)))

    def test_rejects_arg_and_environment_expressions(self):
        source = (
            "ARG JDK_BASE\n"
            "FROM ${JDK_BASE} AS build\n"
            "ARG JRE_BASE\n"
            "FROM $JRE_BASE\n"
        )
        self.assertTrue(self.validate(source))

    def test_rejects_platform_expression(self):
        source = VALID.replace(
            f"FROM {JDK} AS build",
            f"FROM --platform=$BUILDPLATFORM {JDK} AS build",
        )
        self.assertTrue(self.validate(source))

    def test_rejects_additional_stage(self):
        source = VALID + f"FROM {JRE} AS diagnostics\n"
        errors = self.validate(source)
        self.assertTrue(errors)
        self.assertTrue(any("unexpected additional" in error for error in errors))

    def test_rejects_additional_stage_split_across_logical_lines(self):
        source = VALID + "FRO\\\nM alpine\n"

        errors = self.validate(source)

        self.assertTrue(any("found 3" in error for error in errors))
        self.assertTrue(any("unexpected additional" in error for error in errors))

    def test_rejects_stage_after_unsupported_heredoc_marker(self):
        source = (
            VALID
            + "ENV X=<<'HEALTHCHECK NONE'\n"
            + "FRO\\\nM alpine\n"
            + "HEALTHCHECK NONE\n"
        )

        errors = self.validate(source)

        self.assertTrue(any("found 3" in error for error in errors))
        self.assertTrue(any("unexpected additional" in error for error in errors))

    def test_does_not_count_from_text_inside_run_heredoc(self):
        source = VALID.replace(
            "RUN true",
            "RUN <<'EOF'\nFROM alpine\nEOF",
            1,
        )

        self.assertEqual([], self.validate(source))

    def test_does_not_count_from_text_inside_copy_heredoc(self):
        source = VALID.replace(
            "RUN true",
            "COPY <<'EOF' /tmp/example\nFROM alpine\nEOF",
            1,
        )

        self.assertEqual([], self.validate(source))

    def test_allows_package_manager_words_in_copy_heredoc(self):
        source = VALID.replace(
            "RUN true",
            (
                "COPY <<'EOF' /tmp/package-manager-policy.txt\n"
                "apt-get is intentionally unavailable in this image\n"
                "EOF"
            ),
            1,
        )

        self.assertEqual([], self.validate(source))

    def test_publisher_runs_current_master_policy_for_historical_source(self):
        workflow = yaml.safe_load(PUBLISH_WORKFLOW.read_text(encoding="utf-8"))
        steps = workflow["jobs"]["publish"]["steps"]
        verification = next(
            step
            for step in steps
            if step.get("name") == "Verify source against master and release record"
        )["run"]

        self.assertIn(
            'git show \\\n  "$GITHUB_SHA:scripts/ci/verify_backend_base_pins.py" |\n'
            "  PYTHONDONTWRITEBYTECODE=1 python3 - backend/Dockerfile",
            verification,
        )

    def test_cli_accepts_explicit_dockerfile_path(self):
        with tempfile.TemporaryDirectory() as directory:
            dockerfile = Path(directory) / "Dockerfile"
            dockerfile.write_text(VALID, encoding="utf-8")

            self.assertEqual(0, MODULE.main((str(dockerfile),)))

    def test_rejects_reordered_stages(self):
        source = f"FROM {JRE}\nFROM {JDK} AS build\n"
        self.assertTrue(self.validate(source))

    def test_rejects_missing_or_changed_stage_alias(self):
        for replacement in (f"FROM {JDK}", f"FROM {JDK} AS compile"):
            with self.subTest(replacement=replacement):
                self.assertTrue(
                    self.validate(VALID.replace(f"FROM {JDK} AS build", replacement))
                )

    def test_rejects_multiline_or_noncanonical_from_instruction(self):
        source = VALID.replace(
            f"FROM {JDK} AS build",
            f"FROM \\\n  {JDK} AS build",
        )
        self.assertTrue(self.validate(source))

    def test_rejects_mutable_os_package_manager_commands(self):
        commands = (
            "RUN apt-get update",
            "RUN /usr/bin/apt install curl",
            "RUN apk add curl",
            "RUN dnf install curl",
            "RUN yum install curl",
            "RUN microdnf install curl",
        )
        for command in commands:
            with self.subTest(command=command):
                errors = self.validate(VALID.replace("RUN true", command, 1))
                self.assertTrue(
                    any("must not fetch mutable OS packages" in error for error in errors)
                )

    def test_allows_package_manager_names_outside_run_instructions(self):
        instructions = (
            "ARG PACKAGE_MANAGER=apt-get",
            "ENV PACKAGE_MANAGER=apt-get",
            'LABEL org.step-beyond.policy="apt-get is unavailable"',
            "COPY apt-get /tmp/policy",
        )
        for instruction in instructions:
            with self.subTest(instruction=instruction):
                self.assertEqual(
                    [],
                    self.validate(VALID.replace("RUN true", instruction, 1)),
                )

    def test_rejects_package_manager_aliases_used_by_run(self):
        cases = (
            ("ARG PACKAGE_MANAGER=apt-get", "RUN $PACKAGE_MANAGER update"),
            ("ENV PACKAGE_MANAGER=apt-get", "RUN ${PACKAGE_MANAGER} update"),
            (
                "ARG BASE_MANAGER=apt-get\n"
                "ENV PACKAGE_MANAGER=$BASE_MANAGER",
                "RUN $PACKAGE_MANAGER update",
            ),
            (
                "ENV PACKAGE_MANAGER=/usr/bin/apt",
                "RUN <<EOF\n$PACKAGE_MANAGER update\nEOF",
            ),
        )
        for definition, command in cases:
            with self.subTest(definition=definition, command=command):
                source = VALID.replace(
                    "RUN true",
                    f"{definition}\n{command}",
                    1,
                )

                errors = self.validate(source)

                self.assertTrue(
                    any(
                        "must not fetch mutable OS packages" in error
                        and "alias $PACKAGE_MANAGER" in error
                        for error in errors
                    )
                )

    def test_rejects_package_manager_aliases_composed_from_safe_fragments(self):
        cases = (
            VALID.replace(
                "RUN true",
                "ENV PREFIX=ap\n"
                "ENV SUFFIX=t-get\n"
                "ENV PACKAGE_MANAGER=${PREFIX}${SUFFIX}\n"
                "RUN $PACKAGE_MANAGER update",
                1,
            ),
            VALID.replace(
                "RUN true",
                "ARG PREFIX=dn\n"
                "ENV PACKAGE_MANAGER=${PREFIX}f\n"
                "RUN ${PACKAGE_MANAGER} update",
                1,
            ),
            VALID.replace(
                "RUN true",
                "ENV EMPTY=\n"
                "ENV PREFIX=${EMPTY:-ap}\n"
                "ENV PACKAGE_MANAGER=${PREFIX}t-get\n"
                "RUN $PACKAGE_MANAGER update",
                1,
            ),
            VALID.replace(
                "RUN true",
                "ENV PRESENT=1\n"
                "ENV PREFIX=${PRESENT:+dn}\n"
                "ENV PACKAGE_MANAGER=${PREFIX}f\n"
                "RUN $PACKAGE_MANAGER update",
                1,
            ),
            VALID.replace(
                "RUN true",
                "ARG EMPTY\n"
                "ENV PACKAGE_MANAGER=ap${EMPTY}t-get\n"
                "RUN $PACKAGE_MANAGER update",
                1,
            ),
            (
                "ARG PREFIX=mic\n"
                f"FROM {JDK} AS build\n"
                "ARG PREFIX\n"
                "ENV PACKAGE_MANAGER=${PREFIX}rodnf\n"
                "RUN $PACKAGE_MANAGER install curl\n"
                f"FROM {JRE}\nRUN true\n"
            ),
        )
        for source in cases:
            with self.subTest(source=source):
                errors = self.validate(source)

                self.assertTrue(
                    any(
                        "must not fetch mutable OS packages" in error
                        and "alias $PACKAGE_MANAGER" in error
                        for error in errors
                    )
                )

    def test_allows_aliases_composed_into_non_package_manager_commands(self):
        source = VALID.replace(
            "RUN true",
            "ENV PREFIX=print\n"
            "ENV SUFFIX=f\n"
            "ENV COMMAND=${PREFIX}${SUFFIX}\n"
            "RUN $COMMAND done",
            1,
        )

        self.assertEqual([], self.validate(source))

    def test_rejects_nested_expansions_inside_modifier_words(self):
        cases = (
            (
                "ENV PREFIX=ap\n"
                "ENV PACKAGE_MANAGER=${UNSET:-${PREFIX}t-get}\n"
                "RUN $PACKAGE_MANAGER update"
            ),
            (
                "ENV PREFIX=dn\n"
                "ENV PRESENT=1\n"
                "ENV PACKAGE_MANAGER=${PRESENT:+${PREFIX}f}\n"
                "RUN ${PACKAGE_MANAGER} install curl"
            ),
            (
                "ENV PREFIX=ap\n"
                "ENV PACKAGE_MANAGER=${UNSET:-${OTHER:-${PREFIX}t-get}}\n"
                "RUN $PACKAGE_MANAGER update"
            ),
        )
        for command in cases:
            with self.subTest(command=command):
                errors = self.validate(
                    VALID.replace("RUN true", command, 1)
                )

                self.assertTrue(
                    any(
                        "must not fetch mutable OS packages" in error
                        and "alias $PACKAGE_MANAGER" in error
                        for error in errors
                    )
                )

    def test_allows_discarded_package_manager_alternate_conditions(self):
        cases = (
            (
                "ENV PREFIX=ap\n"
                "ENV MANAGER=${PREFIX}t-get\n"
                "ENV COMMAND=${MANAGER:+printf}\n"
                "RUN $COMMAND done"
            ),
            (
                "ENV EMPTY=\n"
                "ENV COMMAND=${EMPTY:+apt-get}\n"
                "RUN $COMMAND done"
            ),
        )
        for command in cases:
            with self.subTest(command=command):
                self.assertEqual(
                    [], self.validate(VALID.replace("RUN true", command, 1))
                )

    def test_rejects_package_managers_revealed_by_trim_modifiers(self):
        commands = (
            (
                "RUN VALUE=apt-getX; PACKAGE_MANAGER=${VALUE%X}; "
                "$PACKAGE_MANAGER update"
            ),
            (
                "RUN VALUE=Xdnf; PACKAGE_MANAGER=${VALUE#X}; "
                "$PACKAGE_MANAGER install curl"
            ),
            (
                "RUN VALUE=apt-getXX; PACKAGE_MANAGER=${VALUE%%X*}; "
                "$PACKAGE_MANAGER update"
            ),
            (
                "RUN VALUE=XXdnf; PACKAGE_MANAGER=${VALUE##*X}; "
                "$PACKAGE_MANAGER install curl"
            ),
        )
        for command in commands:
            with self.subTest(command=command):
                errors = self.validate(
                    VALID.replace("RUN true", command, 1)
                )

                self.assertTrue(
                    any(
                        "must not fetch mutable OS packages" in error
                        for error in errors
                    )
                )

    def test_allows_safe_commands_resolved_by_trim_modifiers(self):
        commands = (
            "RUN VALUE=printfX; COMMAND=${VALUE%X}; $COMMAND done",
            "RUN VALUE=Xprintf; COMMAND=${VALUE#X}; $COMMAND done",
            "RUN VALUE=printfXX; COMMAND=${VALUE%%X*}; $COMMAND done",
            "RUN VALUE=XXprintf; COMMAND=${VALUE##*X}; $COMMAND done",
        )
        for command in commands:
            with self.subTest(command=command):
                self.assertEqual(
                    [], self.validate(VALID.replace("RUN true", command, 1))
                )

    def test_preserves_trim_pattern_quoting(self):
        safe_commands = (
            (
                'RUN VALUE=Xfooapt-get; COMMAND=${VALUE#"Xfoo*"}; '
                "$COMMAND done"
            ),
            (
                "RUN VALUE=Xfooapt-get; COMMAND=${VALUE#'Xfoo*'}; "
                "$COMMAND done"
            ),
            (
                r"RUN VALUE=Xfooapt-get; COMMAND=${VALUE#Xfoo\*}; "
                "$COMMAND done"
            ),
            (
                'RUN VALUE=Xfooapt-get; COMMAND=${VALUE#"Xfoo?"}; '
                "$COMMAND done"
            ),
            (
                'RUN VALUE=Xfooapt-get; COMMAND=${VALUE#"Xfoo[ab]"}; '
                "$COMMAND done"
            ),
        )
        for command in safe_commands:
            with self.subTest(command=command):
                self.assertEqual(
                    [], self.validate(VALID.replace("RUN true", command, 1))
                )

        dangerous_commands = (
            (
                'RUN VALUE=Xfooapt-get; COMMAND=${VALUE#"Xfoo"*}; '
                "$COMMAND update"
            ),
            (
                'RUN PATTERN="Xfoo*"; VALUE=Xfooapt-get; '
                "COMMAND=${VALUE#$PATTERN}; $COMMAND update"
            ),
        )
        for command in dangerous_commands:
            with self.subTest(command=command):
                self.assertTrue(
                    self.validate(VALID.replace("RUN true", command, 1))
                )

    def test_preserves_trim_pattern_quoting_inside_double_quotes(self):
        safe_commands = (
            (
                'RUN VALUE=Xfooapt-get; COMMAND="${VALUE#"Xfoo*"}"; '
                '"$COMMAND" done'
            ),
            (
                'RUN VALUE=Xfooapt-get; COMMAND="${VALUE#Xfoo"*"}"; '
                '"$COMMAND" done'
            ),
            (
                'RUN VALUE=apt-getXfoo; COMMAND="${VALUE%"*Xfoo"}"; '
                '"$COMMAND" done'
            ),
        )
        for command in safe_commands:
            with self.subTest(command=command):
                self.assertEqual(
                    [], self.validate(VALID.replace("RUN true", command, 1))
                )

        dangerous_commands = (
            (
                'RUN VALUE=Xfooapt-get; COMMAND="${VALUE#Xfoo*}"; '
                '"$COMMAND" update'
            ),
            (
                'RUN VALUE=apt-getXfoo; COMMAND="${VALUE%*Xfoo}"; '
                '"$COMMAND" update'
            ),
            (
                'RUN VALUE=Xfooapt-get; COMMAND="${VALUE#"Xfoo"*}"; '
                '"$COMMAND" update'
            ),
            (
                r'RUN PREFIX=ap; VALUE="Xfoo\"Z${PREFIX}t-get"; '
                r'COMMAND=${VALUE#"Xfoo\""?}; $COMMAND update'
            ),
        )
        for command in dangerous_commands:
            with self.subTest(command=command):
                self.assertTrue(
                    self.validate(VALID.replace("RUN true", command, 1))
                )

    def test_rejects_package_managers_composed_inside_run(self):
        commands = (
            (
                "RUN PREFIX=ap; SUFFIX=t-get; "
                "PACKAGE_MANAGER=${PREFIX}${SUFFIX}; "
                "$PACKAGE_MANAGER update"
            ),
            (
                "RUN PREFIX=dn SUFFIX=f PACKAGE_MANAGER=${PREFIX}${SUFFIX}; "
                "${PACKAGE_MANAGER} install curl"
            ),
            (
                "RUN <<'EOF'\n"
                "PREFIX=ap\n"
                "SUFFIX=t-get\n"
                "PACKAGE_MANAGER=${PREFIX}${SUFFIX}\n"
                "$PACKAGE_MANAGER update\n"
                "EOF"
            ),
            (
                "RUN <<'EOF'\n"
                "export PREFIX=dn\n"
                "readonly SUFFIX=f\n"
                "export PACKAGE_MANAGER=${PREFIX}${SUFFIX}\n"
                "${PACKAGE_MANAGER} install curl\n"
                "EOF"
            ),
            (
                "ENV PREFIX=ap\n"
                "RUN PACKAGE_MANAGER=${PREFIX}t-get; "
                "$PACKAGE_MANAGER update"
            ),
        )
        for command in commands:
            with self.subTest(command=command):
                errors = self.validate(
                    VALID.replace("RUN true", command, 1)
                )

                self.assertTrue(
                    any(
                        "must not fetch mutable OS packages" in error
                        for error in errors
                    )
                )

    def test_rejects_package_managers_composed_as_run_executables(self):
        commands = (
            "RUN PREFIX=ap; SUFFIX=t-get; ${PREFIX}${SUFFIX} update",
            (
                "RUN PREFIX=dn; SUFFIX=f; "
                "/usr/bin/${PREFIX}${SUFFIX} install curl"
            ),
            (
                "RUN PREFIX=ap SUFFIX=t-get; "
                "command -p ${PREFIX}${SUFFIX} update"
            ),
            (
                "RUN PREFIX=dn; SUFFIX=f; "
                "exec /usr/bin/${PREFIX}${SUFFIX} install curl"
            ),
            (
                "RUN PREFIX=ap; SUFFIX=t-get; "
                "nohup ${PREFIX}${SUFFIX} update"
            ),
            (
                "RUN PREFIX=ap; SUFFIX=t-get; "
                "env -i COMMAND=${PREFIX}${SUFFIX} "
                "sh -c '$COMMAND update'"
            ),
        )
        for command in commands:
            with self.subTest(command=command):
                self.assertTrue(
                    self.validate(VALID.replace("RUN true", command, 1))
                )

    def test_allows_safe_composed_run_executables_and_arguments(self):
        commands = (
            "RUN PREFIX=print; SUFFIX=f; ${PREFIX}${SUFFIX} done",
            "RUN PREFIX=ap; SUFFIX=t-get; printf ${PREFIX}${SUFFIX}",
            "RUN PREFIX=ap; SUFFIX=t-get; command -v ${PREFIX}${SUFFIX}",
            (
                "RUN PREFIX=print; SUFFIX=f; "
                "PREFIX=ap SUFFIX=t-get ${PREFIX}${SUFFIX} done"
            ),
            (
                "RUN PREFIX=print; SUFFIX=f; "
                "env COMMAND=${PREFIX}${SUFFIX} sh -c '$COMMAND done'"
            ),
            (
                "RUN PREFIX=ap; SUFFIX=t-get; "
                "env --unset=${PREFIX}${SUFFIX} printf done"
            ),
        )
        for command in commands:
            with self.subTest(command=command):
                self.assertEqual(
                    [], self.validate(VALID.replace("RUN true", command, 1))
                )

    def test_rejects_composed_commands_reparsed_by_shells(self):
        commands = (
            (
                'RUN PREFIX=ap; SUFFIX=t-get; '
                'eval "${PREFIX}${SUFFIX} update"'
            ),
            (
                'RUN PREFIX=dn; SUFFIX=f; '
                'eval "${PREFIX}${SUFFIX}" install curl'
            ),
            (
                'RUN PREFIX=ap; SUFFIX=t-get; '
                'sh -c "${PREFIX}${SUFFIX} update"'
            ),
            (
                'RUN PREFIX=dn; SUFFIX=f; '
                '/bin/dash -ec "${PREFIX}${SUFFIX} install curl"'
            ),
            (
                'RUN PREFIX=ap; SUFFIX=t-get; '
                'bash -O extglob -c "${PREFIX}${SUFFIX} update"'
            ),
            (
                'RUN PREFIX=ap; SUFFIX=t-get; '
                'command sh -c "${PREFIX}${SUFFIX} update"'
            ),
            (
                'RUN PREFIX=dn; SUFFIX=f; '
                'exec /bin/sh -c "${PREFIX}${SUFFIX} install curl"'
            ),
            (
                'RUN PREFIX=ap; SUFFIX=t-get; '
                'nohup sh -c "${PREFIX}${SUFFIX} update"'
            ),
            (
                'RUN PREFIX=dn; SUFFIX=f; '
                "env -i PREFIX=${PREFIX} SUFFIX=${SUFFIX} "
                "sh -c '${PREFIX}${SUFFIX} install curl'"
            ),
            (
                'RUN PREFIX=ap; SUFFIX=t-get; '
                'bash --rcfile /dev/null -c "${PREFIX}${SUFFIX} update"'
            ),
        )
        for command in commands:
            with self.subTest(command=command):
                self.assertTrue(
                    self.validate(VALID.replace("RUN true", command, 1))
                )

    def test_allows_safe_commands_reparsed_by_shells(self):
        commands = (
            "RUN eval 'printf done'",
            "RUN sh -c 'printf done'",
            "RUN dash -- script.sh",
            "RUN bash -O extglob -c 'printf done'",
            (
                "RUN PREFIX=ap; SUFFIX=t-get; "
                "eval 'printf \"%s\\n\" \"${PREFIX}${SUFFIX}\"'"
            ),
            (
                'RUN PREFIX=ap; SUFFIX=t-get; '
                'sh -c "printf %s ${PREFIX}${SUFFIX}"'
            ),
        )
        for command in commands:
            with self.subTest(command=command):
                self.assertEqual(
                    [], self.validate(VALID.replace("RUN true", command, 1))
                )

    def test_allows_safe_commands_composed_inside_run(self):
        command = (
            "RUN PREFIX=print; SUFFIX=f; COMMAND=${PREFIX}${SUFFIX}; "
            "$COMMAND done"
        )

        self.assertEqual(
            [], self.validate(VALID.replace("RUN true", command, 1))
        )

    def test_allows_overwritten_or_out_of_stage_package_manager_aliases(self):
        cases = (
            VALID.replace(
                "RUN true",
                "ENV PACKAGE_MANAGER=apt-get\n"
                "ENV PACKAGE_MANAGER=printf\n"
                "RUN $PACKAGE_MANAGER done",
                1,
            ),
            VALID.replace(
                f"FROM {JRE}\nRUN true",
                f"ENV PACKAGE_MANAGER=apt-get\nFROM {JRE}\n"
                "RUN $PACKAGE_MANAGER update",
            ),
        )
        for source in cases:
            with self.subTest(source=source):
                self.assertEqual([], self.validate(source))

    def test_rejects_package_manager_split_across_active_escape_directive(self):
        cases = (
            ("", "\\"),
            ("# escape=\\\n\n", "\\"),
            ("# escape=`\n\n", "`"),
            ("# syntax=docker/dockerfile:1\n#\tEsCaPe = `\n\n", "`"),
        )
        for prefix, escape in cases:
            with self.subTest(prefix=prefix, escape=escape):
                command = f"RUN apt-{escape}\nget update"
                source = prefix + VALID.replace("RUN true", command, 1)

                errors = self.validate(source)

                self.assertTrue(
                    any(
                        "must not fetch mutable OS packages" in error
                        for error in errors
                    )
                )

    def test_rejects_package_manager_split_around_continuation_comment(self):
        for escape_directive, escape in (("", "\\"), ("# escape=`\n\n", "`")):
            with self.subTest(escape=escape):
                command = f"RUN apt-{escape}\n# removed by Dockerfile parser\nget update"
                source = escape_directive + VALID.replace("RUN true", command, 1)

                errors = self.validate(source)

                self.assertTrue(
                    any(
                        "must not fetch mutable OS packages" in error
                        for error in errors
                    )
                )

    def test_rejects_package_manager_split_around_empty_continuation_line(self):
        source = VALID.replace("RUN true", "RUN apt-\\\n\nget update", 1)

        errors = self.validate(source)

        self.assertTrue(
            any("must not fetch mutable OS packages" in error for error in errors)
        )

    def test_rejects_shell_continuations_inside_run_heredoc(self):
        cases = (
            ("", "RUN <<EOF\napt-\\\nget update\nEOF"),
            ("# escape=`\n\n", "RUN <<'EOF'\napt-\\\nget update\nEOF"),
            (
                "# escape=`\n\n",
                "RUN <<-\"EOF\"\n\tapt-\\\n\tget update\n\tEOF",
            ),
        )
        for prefix, command in cases:
            with self.subTest(prefix=prefix, command=command):
                errors = self.validate(
                    prefix + VALID.replace("RUN true", command, 1)
                )

                self.assertTrue(
                    any(
                        "must not fetch mutable OS packages" in error
                        for error in errors
                    )
                )

    def test_rejects_shell_continuations_in_multiple_run_heredocs(self):
        command = (
            "RUN <<FIRST <<SECOND\n"
            "true\n"
            "FIRST\n"
            "apt-\\\n"
            "get update\n"
            "SECOND"
        )
        source = "# escape=`\n\n" + VALID.replace("RUN true", command, 1)

        errors = self.validate(source)

        self.assertTrue(
            any("must not fetch mutable OS packages" in error for error in errors)
        )

    def test_ignores_shift_operators_inside_arithmetic_expansions(self):
        commands = (
            "RUN echo $((1 << 2))",
            "RUN echo $(((1 << 2) + (8 >> 1)))",
            "RUN echo $((1 << $(printf 1)))",
            'RUN test "$((8 >> 1))" = 4',
        )
        for command in commands:
            with self.subTest(command=command):
                self.assertEqual(
                    [], self.validate(VALID.replace("RUN true", command, 1))
                )

    def test_ignores_case_pattern_parentheses_inside_arithmetic_substitutions(self):
        commands = (
            "RUN echo $(( $(case x in a) echo 0 ;; x) echo 1 ;; esac) << 2 ))",
            "RUN echo $(( $(case x in (a) echo 0 ;; (x) echo 1 ;; esac) << 2 ))",
            "RUN echo $(( $(case 1 in 1) echo 1 ;; esac) << 2 ))",
            (
                "RUN echo $(( $(case x in x) case y in y) echo 1 ;; esac ;; "
                "esac) << 2 ))"
            ),
        )
        for command in commands:
            with self.subTest(command=command):
                self.assertEqual(
                    [], self.validate(VALID.replace("RUN true", command, 1))
                )

    def test_does_not_end_case_on_esac_command_arguments(self):
        arguments = ("esac", "esac=value", "esac-command", "1esac")
        for argument in arguments:
            with self.subTest(argument=argument):
                command = (
                    "RUN echo $(( $(case x in "
                    f"x) echo {argument} ;; "
                    "y) echo 0 ;; "
                    "z) echo 1 ;; "
                    "esac) << 2 ))"
                )

                self.assertEqual(
                    [],
                    self.validate(VALID.replace("RUN true", command, 1)),
                )

    def test_preserves_command_start_keywords_inside_case_bodies(self):
        constructs = (
            "if true; then case a in a) : ;; esac; fi",
            "while false; do case a in a) : ;; esac; done",
            "if false; then :; else case a in a) : ;; esac; fi",
            "if false; then :; elif case a in a) : ;; esac; then :; fi",
        )
        for construct in constructs:
            with self.subTest(construct=construct):
                command = (
                    "RUN echo $(( $(case x in x) "
                    f"{construct}; {construct}; "
                    "printf 1 ;; esac) << 2 ))"
                )

                self.assertEqual(
                    [],
                    self.validate(VALID.replace("RUN true", command, 1)),
                )

    def test_does_not_treat_case_arguments_as_case_statements(self):
        declarations, errors = MODULE._here_document_declarations(
            "RUN echo $(( $(printf '%s' case x in a) << 2 ))"
        )

        self.assertEqual((), errors)
        self.assertEqual((), declarations)

    def test_does_not_treat_case_token_prefixes_as_case_statements(self):
        prefixes = ("case=foo", "case-command", "1case")
        for prefix in prefixes:
            with self.subTest(prefix=prefix):
                command = (
                    f"RUN echo $(( $({prefix}; : in; printf 1) )); sh <<EOF\n"
                    "apt-\\\n"
                    "get update\n"
                    "EOF"
                )
                source = "# escape=`\n\n" + VALID.replace(
                    "RUN true",
                    command,
                    1,
                )

                errors = self.validate(source)

                self.assertTrue(
                    any(
                        "must not fetch mutable OS packages" in error
                        for error in errors
                    )
                )

    def test_finds_heredoc_inside_case_body_in_arithmetic_substitution(self):
        declarations, errors = MODULE._here_document_declarations(
            "RUN echo $(( $(case x in a) cat <<EOF ;; esac) << 2 ))"
        )

        self.assertEqual((), errors)
        self.assertEqual((MODULE.HereDocument("EOF", False),), declarations)

    def test_arithmetic_shift_does_not_hide_a_later_run_heredoc(self):
        source = VALID.replace("RUN true", "RUN echo $((1 << 2))", 1)
        source = source.replace(
            "RUN true",
            "RUN <<EOF\napt-\\\nget update\nEOF",
            1,
        )

        errors = self.validate(source)

        self.assertTrue(
            any("must not fetch mutable OS packages" in error for error in errors)
        )

    def test_finds_heredoc_inside_arithmetic_command_substitution(self):
        declarations, errors = MODULE._here_document_declarations(
            "RUN echo $(( $(cat <<EOF) << 1 ))"
        )

        self.assertEqual((), errors)
        self.assertEqual((MODULE.HereDocument("EOF", False),), declarations)

    def test_allows_package_manager_words_in_run_heredoc_comments(self):
        command = (
            "RUN <<EOF\n"
            "# apt-get is intentionally unavailable in this protected build\n"
            "true\n"
            "EOF"
        )
        source = "# escape=`\n\n" + VALID.replace("RUN true", command, 1)

        self.assertEqual([], self.validate(source))

    def test_ignores_quoted_and_here_string_markers(self):
        commands = (
            "RUN printf '%s\\n' '<<EOF'",
            "RUN printf '%s\\n' \"<<EOF\"",
            "RUN printf '%s\\n' value # <<EOF",
            "RUN printf x <<< input",
        )
        for command in commands:
            with self.subTest(command=command):
                self.assertEqual(
                    [], self.validate(VALID.replace("RUN true", command, 1))
                )

    def test_rejects_malformed_run_heredocs(self):
        commands = (
            "RUN <<EOF\ntrue",
            "RUN <<\ntrue",
            "RUN <<'EOF\ntrue",
        )
        for command in commands:
            with self.subTest(command=command):
                errors = self.validate(VALID.replace("RUN true", command, 1))

                self.assertTrue(
                    any("cannot safely parse Dockerfile" in error for error in errors)
                )

    def test_allows_shell_continuation_at_run_heredoc_end(self):
        command = "RUN <<EOF\nprintf done\\\nEOF"
        source = "# escape=`\n\n" + VALID.replace("RUN true", command, 1)

        self.assertEqual([], self.validate(source))

    def test_escape_directive_after_comment_does_not_change_default(self):
        source = (
            "# ordinary comment ends parser-directive processing\n"
            "# escape=`\n"
            + VALID.replace("RUN true", "RUN apt-\\\nget update", 1)
        )

        errors = self.validate(source)

        self.assertTrue(
            any("must not fetch mutable OS packages" in error for error in errors)
        )

    def test_allows_package_manager_words_in_comments(self):
        source = VALID.replace(
            "RUN true",
            "# apt-get is intentionally unavailable in this protected build\nRUN true",
            1,
        )

        self.assertEqual([], self.validate(source))


if __name__ == "__main__":
    unittest.main()
