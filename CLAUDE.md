# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

StoryBuddy is a Python project currently in its initial setup phase. No source code exists yet.

## Development Setup

```bash
# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# or: venv\Scripts\activate  # Windows

# Install dependencies (when requirements exist)
pip install -r requirements.txt  # or use pyproject.toml with pip install -e .
```

## Commands

Commands will be added as the project develops. Expected tools based on .gitignore:
- **Testing:** `pytest`
- **Linting:** `ruff check .` or `ruff format .`
- **Type checking:** `mypy`

## License

Apache License 2.0

## Active Technologies
- Python 3.11 (000-StoryBuddy-mvp)
- SQLite（本地）+ Cloud Storage（語音檔案） (000-StoryBuddy-mvp)

## Recent Changes
- 000-StoryBuddy-mvp: Added Python 3.11
