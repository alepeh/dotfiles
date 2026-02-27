## ADDED Requirements

### Requirement: cmux is declared in Brewfile as a cask dependency
The Brewfile SHALL include `cask "cmux"` so that `brew bundle` installs cmux alongside other dotfiles dependencies.

#### Scenario: Fresh install via brew bundle
- **WHEN** a user runs `brew bundle` from the dotfiles repo
- **THEN** cmux is installed as a Homebrew cask at `/Applications/cmux.app`

#### Scenario: cmux already installed
- **WHEN** cmux is already installed and `brew bundle` runs
- **THEN** the command completes without error and cmux remains at its current version

### Requirement: make doctor verifies cmux is installed
The `make doctor` target SHALL check that the `cmux` CLI binary is available on PATH.

#### Scenario: cmux is installed
- **WHEN** `make doctor` runs and cmux is installed (CLI available via PATH)
- **THEN** the check passes silently and doctor continues

#### Scenario: cmux is not installed
- **WHEN** `make doctor` runs and the `cmux` binary is not found on PATH
- **THEN** the check fails with the message "cmux not found - run: brew install --cask cmux" and exits with a non-zero status
