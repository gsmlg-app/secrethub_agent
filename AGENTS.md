# Codex Development Guidelines

This project is an independent Flutter plugin targeting iOS and Android. For design specifications, refer to [Dart / Flutter Mobile Agent Design](https://github.com/gsmlg-app/secrethub_agent/blob/main/DESIGN.md). Determine the scope of work based on the checked-out design specifications and current task instructions.

The current repository delivers the design documentation, initial Flutter plugin structure, and CI/CD automation. When receiving development tasks, implement strictly within their authorized scope; documentation tasks remain scoped to documentation, and committing, releasing, or deploying must follow task instructions.

## Project Boundaries

- Deliver Dart API, Swift/Kotlin native adaptations, example app, protocol vectors, tests, and usage documentation.
- Core is an external service; this project contains no server-side source code, database migrations, or admin UI.
- When required Core capabilities are missing, report version incompatibility and list integration dependencies; do not adopt fallback protocols that weaken identity or authorization.
- Do not introduce user accounts or admin login systems.

## Security Constraints

- Installation identity and TLS private keys must be generated and held exclusively by native platform keystores and must remain non-exportable; never pass them through Dart or temporary PEM files.
- Secret plaintext must undergo native audit admission and delivery checks before crossing native platform boundaries; offline reads must additionally verify grant validity, cache integrity, trusted clock, and invalidation state.
- Known Core rejections, revocations, TLS trust errors, and synchronization barriers take precedence over offline cache.
- Offline cold starts rely on a trusted OS clock; do not claim resistance against coordinated whole-device time and storage rollbacks.
- Secrets, tokens, private keys, cache encryption keys, and secret-derived digests must never enter logs, exception text, or example outputs.

## Workflow & Verification

- Review existing changes before starting work; preserve the work of others. Prioritize existing dependencies and direct data flows over unnecessary abstractions.
- Work on the current branch; create branches or Git worktrees only when explicitly requested by the user.
- Verify the end-to-end vertical path (native keys → CSR → Core issuance → native mTLS WSS) on physical devices before expanding remaining implementations.
- Organize evidence against the 30 acceptance criteria defined in `DESIGN.md`. Report status as Passed, Failed, Not Executed, or Environment Blocked; simulator or build success cannot substitute for physical device results.
- Do not deploy production services or modify the external Core project unless authorized.

## Agent Skills

- [verification-before-completion](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md): Back completion claims with actual command outputs; preserve the distinction between simulated/mock testing and physical device verification.
