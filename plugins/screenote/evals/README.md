# Evaluations

Screenote's offline checks validate the shared skill tree, the argv-safe CLI
launcher, generated Pi/OpenClaw adapters, manifests, and trigger fixtures:

```bash
bash evals/lint-skills.sh
bash evals/lint-skills-test.sh
python3 evals/validate-plugin.py
```

The lint requires only Bash, grep, and Python 3. It checks the approved command
tuples, project and authentication guidance, JSON exit handling, private file
permissions, and removal of retired transport configuration. Mutation fixtures
prove that allowlist drift, transport metadata, credential arguments,
duplicate-prone image retries, and text-only image fallbacks fail.

`trigger-eval-set.json` maps representative requests to `screenote`, `snapshot`,
or `feedback`, with unrelated controls. Language-model trigger evaluation can
run separately when a host exposes stable skill-match telemetry.

Repository-level tests under `tests/` provide the mock executable, error
scenarios, cleanup checks, and credential-sentinel scans. No offline check needs
a Screenote account or credential.
