"""
SecondBrain Memory MCP Server

Provides semantic search across the SecondBrain knowledge store.
Agents call these tools to retrieve relevant context before responding.

Tools:
  - search_memory: Semantic search across all knowledge
  - get_recent_context: Load MEMORY.md + recent daily logs
  - get_entity: Direct lookup of a person/company/tool/concept
  - get_decisions: Search past decisions
  - get_personal_model: Retrieve identity, preferences, frameworks
  - rebuild_index: Incrementally rebuild the search index
"""

import json
import hashlib
import os
import sys
import glob
import logging
from datetime import datetime, timedelta
from pathlib import Path
from contextlib import asynccontextmanager

# MCP SDK
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

# Embeddings
import openai
import numpy as np

logging.basicConfig(level=logging.INFO, stream=sys.stderr)
logger = logging.getLogger("secondbrain-memory")

# --- Configuration ---

SECONDBRAIN_ROOT = os.environ.get(
    "SECONDBRAIN_ROOT",
    str(Path(__file__).resolve().parent.parent.parent.parent)
)
INDEX_DIR = os.environ.get("SECONDBRAIN_INDEX_DIR", str(Path(__file__).parent))
INDEX_FILE = os.path.join(INDEX_DIR, "index.json")
EMBEDDING_MODEL = os.environ.get("EMBEDDING_MODEL", "text-embedding-3-small")
EMBEDDING_DIMENSIONS = int(os.environ.get("EMBEDDING_DIMENSIONS", "512"))
TOP_K = int(os.environ.get("SECONDBRAIN_TOP_K", "8"))

# Directories to index
KNOWLEDGE_DIRS = [
    "06-Knowledge/Entities",
    "06-Knowledge/Decisions",
    "06-Knowledge/Beliefs",
    "06-Knowledge/Learnings",
    "06-Knowledge/Patterns",
    "06-Knowledge/Threads",
    "07-PersonalModel",
]

# Additional files to index
EXTRA_FILES = [
    "BrainIndex.md",
    "MEMORY.md",
    "06-Knowledge/_Index.md",
    "06-Knowledge/_ConnectionLog.md",
]

# Max chunk size in characters
CHUNK_SIZE = 1500
CHUNK_OVERLAP = 200

# --- Embedding & Index ---

oai_client = None


def get_oai_client():
    global oai_client
    if oai_client is None:
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY environment variable is required")
        oai_client = openai.OpenAI(api_key=api_key)
    return oai_client


def chunk_text(text: str, chunk_size: int = CHUNK_SIZE, overlap: int = CHUNK_OVERLAP) -> list[str]:
    """Split text into overlapping chunks."""
    if len(text) <= chunk_size:
        return [text]
    chunks = []
    start = 0
    while start < len(text):
        end = start + chunk_size
        chunk = text[start:end]
        chunks.append(chunk)
        start = end - overlap
    return chunks


def file_hash(content: str) -> str:
    return hashlib.md5(content.encode()).hexdigest()


def get_embedding(text: str) -> list[float]:
    """Get embedding for a single text."""
    client = get_oai_client()
    response = client.embeddings.create(
        model=EMBEDDING_MODEL,
        input=text,
        dimensions=EMBEDDING_DIMENSIONS,
    )
    return response.data[0].embedding


def get_embeddings_batch(texts: list[str]) -> list[list[float]]:
    """Get embeddings for a batch of texts."""
    if not texts:
        return []
    client = get_oai_client()
    # OpenAI batch limit is 2048
    all_embeddings = []
    for i in range(0, len(texts), 2048):
        batch = texts[i:i + 2048]
        response = client.embeddings.create(
            model=EMBEDDING_MODEL,
            input=batch,
            dimensions=EMBEDDING_DIMENSIONS,
        )
        all_embeddings.extend([d.embedding for d in response.data])
    return all_embeddings


def cosine_similarity(a: list[float], b: list[float]) -> float:
    a_arr = np.array(a)
    b_arr = np.array(b)
    dot = np.dot(a_arr, b_arr)
    norm = np.linalg.norm(a_arr) * np.linalg.norm(b_arr)
    if norm == 0:
        return 0.0
    return float(dot / norm)


def collect_files() -> list[str]:
    """Collect all markdown files to index."""
    files = []
    for d in KNOWLEDGE_DIRS:
        full_dir = os.path.join(SECONDBRAIN_ROOT, d)
        if os.path.isdir(full_dir):
            for f in glob.glob(os.path.join(full_dir, "**/*.md"), recursive=True):
                files.append(f)
    for f in EXTRA_FILES:
        full_path = os.path.join(SECONDBRAIN_ROOT, f)
        if os.path.isfile(full_path):
            files.append(full_path)
    return sorted(set(files))


def load_index() -> dict:
    """Load the existing index from disk."""
    if os.path.exists(INDEX_FILE):
        with open(INDEX_FILE, "r") as f:
            return json.load(f)
    return {"files": {}, "chunks": []}


def save_index(index: dict):
    """Save the index to disk."""
    with open(INDEX_FILE, "w") as f:
        json.dump(index, f)


def build_index(incremental: bool = True) -> dict:
    """Build or incrementally update the embedding index."""
    index = load_index() if incremental else {"files": {}, "chunks": []}
    files = collect_files()

    # Determine which files need (re-)indexing
    new_chunks_texts = []
    new_chunks_meta = []
    current_files = set()

    for filepath in files:
        rel_path = os.path.relpath(filepath, SECONDBRAIN_ROOT)
        current_files.add(rel_path)

        with open(filepath, "r", errors="replace") as f:
            content = f.read()

        content_hash = file_hash(content)

        # Skip if unchanged
        if rel_path in index["files"] and index["files"][rel_path] == content_hash:
            continue

        # Remove old chunks for this file
        index["chunks"] = [c for c in index["chunks"] if c["file"] != rel_path]
        index["files"][rel_path] = content_hash

        # Chunk and queue for embedding
        chunks = chunk_text(content)
        for i, chunk in enumerate(chunks):
            new_chunks_texts.append(chunk)
            new_chunks_meta.append({
                "file": rel_path,
                "chunk_index": i,
                "preview": chunk[:200],
            })

    # Remove entries for deleted files
    deleted = set(index["files"].keys()) - current_files
    for d in deleted:
        index["chunks"] = [c for c in index["chunks"] if c["file"] != d]
        del index["files"][d]

    # Embed new chunks
    if new_chunks_texts:
        logger.info(f"Embedding {len(new_chunks_texts)} new chunks...")
        embeddings = get_embeddings_batch(new_chunks_texts)
        for meta, embedding in zip(new_chunks_meta, embeddings):
            meta["embedding"] = embedding
            index["chunks"].append(meta)
        logger.info(f"Index updated: {len(index['chunks'])} total chunks, {len(index['files'])} files")

    save_index(index)
    return index


def search_index(query: str, top_k: int = TOP_K, file_filter: str | None = None) -> list[dict]:
    """Search the index for chunks similar to the query."""
    index = load_index()
    if not index["chunks"]:
        return []

    query_embedding = get_embedding(query)

    results = []
    for chunk in index["chunks"]:
        if file_filter and file_filter not in chunk["file"]:
            continue
        score = cosine_similarity(query_embedding, chunk["embedding"])
        results.append({
            "file": chunk["file"],
            "score": round(score, 4),
            "preview": chunk["preview"],
        })

    results.sort(key=lambda x: x["score"], reverse=True)
    return results[:top_k]


def read_file(rel_path: str) -> str:
    """Read a file from the SecondBrain."""
    full_path = os.path.join(SECONDBRAIN_ROOT, rel_path)
    if not os.path.isfile(full_path):
        return f"File not found: {rel_path}"
    with open(full_path, "r", errors="replace") as f:
        return f.read()


# --- MCP Server ---

app = Server("secondbrain-memory")


@app.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="search_memory",
            description="Semantic search across the SecondBrain knowledge store. Returns the most relevant chunks with file paths and similarity scores.",
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Natural language search query",
                    },
                    "top_k": {
                        "type": "integer",
                        "description": f"Number of results to return (default: {TOP_K})",
                        "default": TOP_K,
                    },
                    "filter": {
                        "type": "string",
                        "description": "Filter results to files containing this string in their path (e.g., 'Entities', 'Decisions', 'Beliefs')",
                    },
                },
                "required": ["query"],
            },
        ),
        Tool(
            name="get_recent_context",
            description="Load MEMORY.md and recent daily logs for session startup context.",
            inputSchema={
                "type": "object",
                "properties": {
                    "days": {
                        "type": "integer",
                        "description": "Number of days of daily logs to include (default: 3)",
                        "default": 3,
                    },
                },
            },
        ),
        Tool(
            name="get_entity",
            description="Look up a specific entity (person, company, tool, concept) by name.",
            inputSchema={
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Entity name to look up (e.g., 'simon-beard', 'gabe', 'openrouter')",
                    },
                },
                "required": ["name"],
            },
        ),
        Tool(
            name="get_decisions",
            description="Search past decisions by topic. Returns decision records with context and rationale.",
            inputSchema={
                "type": "object",
                "properties": {
                    "topic": {
                        "type": "string",
                        "description": "Topic to search decisions for",
                    },
                    "top_k": {
                        "type": "integer",
                        "description": "Number of results (default: 5)",
                        "default": 5,
                    },
                },
                "required": ["topic"],
            },
        ),
        Tool(
            name="get_personal_model",
            description="Retrieve Dan's personal model — identity, preferences, communication style, decision frameworks, and recurring themes.",
            inputSchema={
                "type": "object",
                "properties": {
                    "section": {
                        "type": "string",
                        "description": "Specific section to retrieve: 'identity', 'preferences', 'frameworks', 'themes', 'style', or 'all' (default: 'all')",
                        "default": "all",
                    },
                },
            },
        ),
        Tool(
            name="rebuild_index",
            description="Incrementally rebuild the semantic search index. Only re-embeds changed files.",
            inputSchema={
                "type": "object",
                "properties": {
                    "full": {
                        "type": "boolean",
                        "description": "If true, rebuild from scratch instead of incrementally (default: false)",
                        "default": False,
                    },
                },
            },
        ),
    ]


@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    try:
        if name == "search_memory":
            query = arguments["query"]
            top_k = arguments.get("top_k", TOP_K)
            file_filter = arguments.get("filter")
            results = search_index(query, top_k, file_filter)
            if not results:
                return [TextContent(type="text", text="No results found. The index may need to be built — call rebuild_index first.")]
            output_parts = [f"## Search results for: {query}\n"]
            for i, r in enumerate(results, 1):
                output_parts.append(f"### {i}. {r['file']} (score: {r['score']})\n{r['preview']}...\n")
            return [TextContent(type="text", text="\n".join(output_parts))]

        elif name == "get_recent_context":
            days = arguments.get("days", 3)
            parts = []

            # MEMORY.md
            memory = read_file("MEMORY.md")
            parts.append(f"## MEMORY.md\n\n{memory}")

            # Recent daily logs
            today = datetime.now()
            for i in range(days):
                date = today - timedelta(days=i)
                date_str = date.strftime("%Y-%m-%d")
                daily = read_file(f"01-Daily/{date_str}.md")
                if "File not found" not in daily:
                    parts.append(f"## Daily Log: {date_str}\n\n{daily}")

            # Tasks
            tasks = read_file("00-Tasks/Tasks.md")
            if "File not found" not in tasks:
                parts.append(f"## Tasks\n\n{tasks}")

            return [TextContent(type="text", text="\n\n---\n\n".join(parts))]

        elif name == "get_entity":
            entity_name = arguments["name"].lower().replace(" ", "-")
            # Try direct file lookup
            entity_path = f"06-Knowledge/Entities/{entity_name}.md"
            content = read_file(entity_path)
            if "File not found" not in content:
                return [TextContent(type="text", text=f"## Entity: {entity_name}\n\n{content}")]
            # Try search as fallback
            results = search_index(arguments["name"], top_k=3, file_filter="Entities")
            if results:
                parts = [f"## Entity search: {arguments['name']}\n\nDirect file not found. Similar entities:\n"]
                for r in results:
                    file_content = read_file(r["file"])
                    parts.append(f"### {r['file']} (score: {r['score']})\n{file_content}\n")
                return [TextContent(type="text", text="\n".join(parts))]
            return [TextContent(type="text", text=f"No entity found for: {arguments['name']}")]

        elif name == "get_decisions":
            topic = arguments["topic"]
            top_k = arguments.get("top_k", 5)
            results = search_index(topic, top_k, file_filter="Decisions")
            if not results:
                return [TextContent(type="text", text=f"No decisions found for: {topic}")]
            parts = [f"## Decisions related to: {topic}\n"]
            for i, r in enumerate(results, 1):
                file_content = read_file(r["file"])
                parts.append(f"### {i}. {r['file']} (score: {r['score']})\n{file_content}\n")
            return [TextContent(type="text", text="\n".join(parts))]

        elif name == "get_personal_model":
            section = arguments.get("section", "all")
            section_map = {
                "identity": "07-PersonalModel/Identity.md",
                "preferences": "07-PersonalModel/Preferences.md",
                "frameworks": "07-PersonalModel/DecisionFrameworks.md",
                "themes": "07-PersonalModel/Themes.md",
                "style": "07-PersonalModel/CommunicationStyle.md",
            }
            if section == "all":
                parts = []
                for key, path in section_map.items():
                    content = read_file(path)
                    if "File not found" not in content:
                        parts.append(f"## {key.title()}\n\n{content}")
                return [TextContent(type="text", text="\n\n---\n\n".join(parts))]
            elif section in section_map:
                content = read_file(section_map[section])
                return [TextContent(type="text", text=content)]
            else:
                return [TextContent(type="text", text=f"Unknown section: {section}. Options: {', '.join(list(section_map.keys()) + ['all'])}")]

        elif name == "rebuild_index":
            full = arguments.get("full", False)
            index = build_index(incremental=not full)
            return [TextContent(
                type="text",
                text=f"Index rebuilt. {len(index['chunks'])} chunks across {len(index['files'])} files.",
            )]

        else:
            return [TextContent(type="text", text=f"Unknown tool: {name}")]

    except Exception as e:
        logger.error(f"Error in {name}: {e}", exc_info=True)
        return [TextContent(type="text", text=f"Error: {str(e)}")]


async def main():
    logger.info(f"SecondBrain Memory MCP Server starting...")
    logger.info(f"  Root: {SECONDBRAIN_ROOT}")
    logger.info(f"  Index: {INDEX_FILE}")
    logger.info(f"  Model: {EMBEDDING_MODEL} ({EMBEDDING_DIMENSIONS}d)")

    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
