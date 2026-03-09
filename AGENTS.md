# PayBoard Repository Rules

## Repository Layout
- Git root is the `payboard/` directory.
- iOS app and Swift package live in `ios/`.
- Android app should live in `android/`.

## Commit Rules
- Use conventional commits: `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`, `test:`.
- Write the commit subject in Korean.
- Keep the subject to a single clear change unit.
- Split unrelated work into separate commits.
- Prefer `chore:` for repo structure, config wiring, and tooling changes.
- Prefer `feat:` for user-facing behavior or new product capability.
- After completing a requested change that modifies files, create the relevant commit by default unless the user explicitly says not to.
- Stage and commit only the files related to the completed task; leave unrelated working tree changes untouched.

## Local Config
- Do not commit local secret/config files such as `ios/Payboard.xcconfig`.
- Commit only example templates intended for sharing.
