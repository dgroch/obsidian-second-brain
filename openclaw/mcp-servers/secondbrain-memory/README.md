# SecondBrain Memory MCP Server

An MCP server that gives OpenClaw agents semantic search access to the SecondBrain knowledge store. Agents can search your knowledge graph before responding, surface relevant entities, decisions, and beliefs automatically.

## How It Works

```
You send message → OpenClaw agent receives it
                 → Agent calls search_memory (MCP tool)
                 → Server searches embedding index of SecondBrain
                 → Relevant context returned to agent
                 → Agent responds with full knowledge context
```

## Tools Provided

| Tool | Purpose |
|------|---------|
| `search_memory` | Semantic search across all knowledge (entities, decisions, beliefs, learnings, patterns, threads) |
| `get_recent_context` | Load MEMORY.md + recent daily logs + Tasks.md for session startup |
| `get_entity` | Direct lookup of a person, company, tool, or concept |
| `get_decisions` | Search past decisions with rationale and context |
| `get_personal_model` | Retrieve Dan's identity, preferences, communication style, frameworks |
| `rebuild_index` | Incrementally rebuild the search index |

## Setup

### 1. Install Dependencies

```bash
cd 99-System/mcp-servers/secondbrain-memory
export OPENAI_API_KEY=sk-...
./setup.sh
```

This creates a Python virtual environment, installs dependencies, and builds the initial search index.

### 2. Configure mcporter

**Important:** OpenClaw uses `mcporter` for MCP servers, not the `mcpServers` key in `openclaw.json`.

Add to your **mcporter config** (usually `~/.openclaw/workspace/config/mcporter.json` or `~/.config/mcporter/config.json`):

```json
{
  "mcpServers": {
    "secondbrain-memory": {
      "command": "/path/to/secondbrain/99-System/mcp-servers/secondbrain-memory/.venv/bin/python",
      "args": ["/path/to/secondbrain/99-System/mcp-servers/secondbrain-memory/server.py"],
      "env": {
        "OPENAI_API_KEY": "sk-...",
        "SECONDBRAIN_ROOT": "/path/to/secondbrain"
      }
    }
  }
}
```

**Note:** Use full absolute paths. The `setup.sh` script prints the exact config block for you.

### 3. Verify Installation

```bash
# List all MCP servers
mcporter list

# Should show: secondbrain-memory (6 tools, healthy)

# Test search
mcporter call secondbrain-memory.search_memory query="your query"
```

### 4. (Optional) Restart OpenClaw

If OpenClaw was running during setup:
```bash
openclaw gateway restart
```

## Keeping the Index Fresh

The index is incremental — it only re-embeds changed files.

1. **Cron job** (recommended): Add to your evening synthesis cron
   ```
   15 23 * * * /path/to/secondbrain/99-System/mcp-servers/secondbrain-memory/refresh-index.sh
   ```

2. **Agent-triggered**: Any agent can call the `rebuild_index` tool

3. **Manual**: Run `./refresh-index.sh` anytime

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENAI_API_KEY` | (required) | OpenAI API key for embeddings |
| `SECONDBRAIN_ROOT` | auto-detected | Path to SecondBrain root |
| `SECONDBRAIN_INDEX_DIR` | server directory | Where to store index.json |
| `EMBEDDING_MODEL` | text-embedding-3-small | OpenAI embedding model |
| `EMBEDDING_DIMENSIONS` | 512 | Embedding dimensions |
| `SECONDBRAIN_TOP_K` | 8 | Default search results count |

## Files

| File | Purpose |
|------|---------|
| `server.py` | MCP server with 6 tools |
| `setup.sh` | One-time setup (venv + deps + initial index) |
| `refresh-index.sh` | Incremental index rebuild |
| `requirements.txt` | Python dependencies |
| `index.json` | Embedding index (auto-generated, gitignored) |

## Troubleshooting

### Server not showing in `mcporter list`

- Verify the config file path with `mcporter config list`
- Ensure paths in the config are absolute (not relative)
- Check that the virtual environment exists at the specified path

### "OPENAI_API_KEY environment variable is required"

Set the key in your mcporter config's `env` block and in your shell for setup.

### Index is empty

Run `rebuild_index` tool or `./refresh-index.sh` to build the index.
