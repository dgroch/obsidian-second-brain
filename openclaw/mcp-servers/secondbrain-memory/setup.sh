#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== SecondBrain Memory MCP Server Setup ==="

# Check for OPENAI_API_KEY
if [ -z "${OPENAI_API_KEY:-}" ]; then
    echo "ERROR: OPENAI_API_KEY environment variable is required."
    echo "  export OPENAI_API_KEY=sk-..."
    exit 1
fi

# Create virtual environment
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv .venv
fi

echo "Installing dependencies..."
.venv/bin/pip install -q -r requirements.txt

# Build initial index
echo "Building initial search index..."
SECONDBRAIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SECONDBRAIN_ROOT="$SECONDBRAIN_ROOT" .venv/bin/python -c "
import sys
sys.path.insert(0, '$SCRIPT_DIR')
from server import build_index
index = build_index(incremental=False)
print(f'Indexed {len(index[\"chunks\"])} chunks across {len(index[\"files\"])} files.')
"

echo ""
echo "=== Setup complete ==="
echo ""
echo "To register with mcporter, add to your mcporter config:"
echo ""
echo '  "secondbrain-memory": {'
echo "    \"command\": \"$SCRIPT_DIR/.venv/bin/python\","
echo "    \"args\": [\"$SCRIPT_DIR/server.py\"],"
echo '    "env": {'
echo "      \"OPENAI_API_KEY\": \"$OPENAI_API_KEY\","
echo "      \"SECONDBRAIN_ROOT\": \"$SECONDBRAIN_ROOT\""
echo '    }'
echo '  }'
