#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SECONDBRAIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

export SECONDBRAIN_ROOT

"$SCRIPT_DIR/.venv/bin/python" -c "
import sys
sys.path.insert(0, '$SCRIPT_DIR')
from server import build_index
index = build_index(incremental=True)
print(f'Index refreshed: {len(index[\"chunks\"])} chunks across {len(index[\"files\"])} files.')
"
