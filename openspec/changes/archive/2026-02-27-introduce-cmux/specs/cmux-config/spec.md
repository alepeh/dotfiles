## ADDED Requirements

### Requirement: Ghostty config is managed in the dotfiles repo
A Ghostty configuration file SHALL exist at `ghostty/config` in the dotfiles repo and be symlinked to `~/.config/ghostty/config` during installation.

#### Scenario: Config is symlinked on install
- **WHEN** a user runs `make install` (or `make ghostty`)
- **THEN** the directory `ghostty/` is symlinked to `~/.config/ghostty/` so that cmux and Ghostty read the config

#### Scenario: Ghostty config directory already exists
- **WHEN** `~/.config/ghostty` already exists as a regular directory (not a symlink)
- **THEN** the install warns the user and does not overwrite the existing config

### Requirement: Ghostty config sets font, theme, and appearance
The Ghostty config SHALL specify the MesloLGS Nerd Font family, a font size, the catppuccin-mocha theme, and window padding to match the existing terminal appearance.

#### Scenario: cmux reads the Ghostty config
- **WHEN** cmux launches
- **THEN** it uses MesloLGS Nerd Font, catppuccin-mocha colors, and the configured font size and padding

### Requirement: Makefile has a ghostty target
The Makefile SHALL include a `ghostty` target that symlinks the Ghostty config directory, following the same pattern as the `helix` and `zellij` targets.

#### Scenario: Running make ghostty
- **WHEN** a user runs `make ghostty`
- **THEN** `ghostty/` from the repo is symlinked to `~/.config/ghostty/`

#### Scenario: ghostty target is part of install
- **WHEN** a user runs `make install`
- **THEN** the `ghostty` target runs as part of the install sequence
