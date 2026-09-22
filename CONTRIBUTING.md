# Contributing to heat

Thank you for contributing to heat. Everything is welcome, from small documentation fixes to feature PRs.

## Code of Conduct

Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before participating.

## Development environment

- macOS 14+
- Xcode Command Line Tools (`xcode-select --install`)
- Git

Build:

```bash
./scripts/build-app.sh
open dist/Heat.app
```

`dist/` is not committed to git.

## Issues

Report bugs and feature requests on GitHub Issues.

When filing a bug, please include if possible:

- macOS version / chip (Apple Silicon / Intel)
- heat version or commit
- Steps to reproduce
- Expected behavior vs actual behavior
- (Sensor issues) whether the admin sampler was approved

For security issues, contact the maintainer privately instead of opening a public issue.

## Pull request flow

**Do not push directly to `main`.** All changes go through PRs.

1. Create a branch from the latest `main`
   `git checkout -b fix/short-description`
2. Make changes and verify with a local build and run
3. Open a PR (briefly describe what changed and why)
4. Address review feedback, then merge

### Commit messages

English is recommended.

```
prefix: short subject

- bullets explaining why / what changed
```

Prefix examples: `feat`, `fix`, `update`, `refactor`, `docs`, `chore`, `style`

### PR checklist

- [ ] `./scripts/build-app.sh` succeeds
- [ ] Menu bar and popover basic behavior verified
- [ ] If permissions/LaunchDaemon changed, update the permission table in README
- [ ] No secrets, local paths, or `dist/` included

## Code guidelines

- Keep the menu bar UX simple: heat and memory at a glance, causes and quit one click away
- Don't rely on default SwiftUI `List`/`ScrollView` padding; keep the existing AppKit `TopPinnedScroll` pattern for the process list
- When changing the privileged helper (`heat-sampler`), keep the permission and uninstall procedures in sync with the README
- Killing system-protected processes must remain blocked (`ProcessActions`)

## License

Contributions are licensed under the same [MIT License](LICENSE) as the project.
