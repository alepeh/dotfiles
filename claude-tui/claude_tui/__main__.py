"""Entry point: python -m claude_tui  /  uv run claude-tui."""

from claude_tui.app import ClaudeTUI


def main():
    app = ClaudeTUI()
    app.run()


if __name__ == "__main__":
    main()
