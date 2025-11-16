#!/bin/bash
# Minimal production requirements sync for hyprchrp
# Regenerates requirements.txt via `uv pip freeze`

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🔄 Regenerating requirements files using uv export${NC}"

if [[ ! -f "$PACKAGE_ROOT/pyproject.toml" ]]; then
    echo -e "${RED}❌ Error: pyproject.toml not found. Run this script from the hyprchrp repository.${NC}"
    exit 1
fi

cd "$PACKAGE_ROOT"

if ! command -v uv >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: uv is required. Install uv or run ./scripts/dev-setup.sh first.${NC}"
    exit 1
fi

echo -e "${BLUE}📦 Running: uv export --no-dev${NC}"
uv export --no-dev --format=requirements-txt --output-file requirements.txt
echo -e "${GREEN}✓ requirements.txt updated via uv export (production only)${NC}"

echo -e "${BLUE}🛠️ Running: uv export --only-group dev${NC}"
uv export --only-group dev --format=requirements-txt --output-file requirements-dev.txt
echo -e "${GREEN}✓ requirements-dev.txt updated via uv export (dev tools)${NC}"

echo -e "${BLUE}Next steps:${NC}"
echo "  - Review requirements.txt and requirements-dev.txt"
echo "  - Commit updated dependency files as needed"