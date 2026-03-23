---
name: secondbrain-manager
description: Manages Dan's SecondBrain knowledge base. Captures data from Trello, Slack, Gmail, Telegram, and Fireflies. Synthesises raw data into structured knowledge. Maintains entity connections, belief tracking, pattern detection, and a living personal model. Run after every substantive interaction.
---

# SecondBrain Manager

**Purpose:** Maintain the SecondBrain knowledge base — daily data capture, synthesis, integration, and connection across all sources.

**Repo:** `dgroch/secondbrain` (GitHub, synced via Obsidian Git)
**User:** Daniel Groch | Timezone: Australia/Melbourne (AEST/AEDT)

---

## Philosophy

- **Text > brain** — If it's worth remembering, it goes in a file
- **Connections > isolation** — Every piece of knowledge links to related pieces via `[[wikilinks]]`
- **Synthesis > accumulation** — Raw information is processed into decisions, beliefs, learnings, and patterns
- **Living > static** — The personal model and knowledge index are continuously updated
- **Never delete** — Archive to `08-Archive/`, don't destroy. Old knowledge may become relevant again

---

## Vault Structure

```
01-Daily/            Daily journals + Tasks.md
02-Weekly/           Weekly reviews + monthly/quarterly reports
03-Projects/         Active projects
04-Meetings/         Meeting notes (Fireflies.ai transcripts)
05-Resources/        Reference material, podcasts, prompts
06-Knowledge/        Structured knowledge store
  ├── Entities/      People, companies, tools, concepts
  ├── Decisions/     Dated decision records with rationale
  ├── Beliefs/       Dan's beliefs with confidence scores and evidence
  ├── Learnings/     Indexed lessons learned
  ├── Patterns/      Recurring themes detected by synthesis
  ├── Threads/       Important conversation threads and open questions
  ├── _Index.md      Master index of all knowledge
  └── _ConnectionLog.md  Relationship graph between entities
07-PersonalModel/    Dan's identity, preferences, decision frameworks, themes
  ├── Identity.md
  ├── DecisionFrameworks.md
  ├── CommunicationStyle.md
  ├── Themes.md
  ├── Preferences.md
  └── _Changelog.md
08-Archive/          Completed/inactive (mirrors source structure)
99-System/
  ├── mcp-servers/secondbrain-memory/  MCP server for semantic search
  └── Skills/secondbrain-manager/      This skill
```

**Key files:**
- `BrainIndex.md` — Loaded into every session. Start here.
- `MEMORY.md` — Quick-reference memory summary
- `00-Tasks/Tasks.md` — Active task list (**DO NOT auto-modify without explicit user request**)

---

## Data Sources

| Source | What to Capture | How |
|--------|----------------|-----|
| **Trello** | Board changes, card movements, comments | Trello API: poll boards every 4h, extract new/moved/completed cards |
| **Slack** | Key messages, decisions, action items | Slack Socket Mode: filter for mentions, threads, decisions |
| **Email (Gmail)** | Important correspondence, action items | Gmail API / MCP: scan inbox for flagged/starred, extract summaries |
| **Telegram** | Commands, conversations, quick captures | OpenClaw channel: already connected, capture substantive exchanges |
| **Fireflies.ai** | Meeting transcripts, action items, decisions | Fireflies API: poll for new transcripts, extract structured data |

---

## Context Loading Protocol

### Every Session Start

1. Read `BrainIndex.md` — vault structure and memory protocol
2. Read `MEMORY.md` — recent activity and project status
3. Read `07-PersonalModel/Identity.md` — Dan's values, context, preferences

This gives you Dan's identity, current state, and quick reference to all knowledge.

### Topic-Specific Loading

If the conversation is about a specific topic:
1. Search `06-Knowledge/Entities/` for related files
2. Search `06-Knowledge/Decisions/` for relevant decisions
3. Check `06-Knowledge/Beliefs/` for Dan's position on related topics
4. Check `06-Knowledge/Threads/` for active threads

### Following Up on Previous Conversations

1. Check `06-Knowledge/Threads/` for active threads
2. Check recent daily journals in `01-Daily/` for context

---

## Connection Protocol

**Run this after every substantive interaction with Dan.**

### Step 1: Entity Extraction

Scan the conversation for mentions of:
- **People** — names, roles, relationships
- **Companies/organisations** — employers, partners, competitors
- **Tools/technologies** — software, APIs, services
- **Concepts** — ideas, frameworks, mental models

### Step 2: Entity Resolution

For each entity found:
1. Search `06-Knowledge/Entities/` for an existing file
2. If found → update the file with new information, bump `last_updated`
3. If not found AND the entity is significant (mentioned in a decision, has a relationship to Dan, or is relevant to an active project) → create a new file using the appropriate template (see Templates section)

### Step 3: Bi-directional Linking

When creating or updating any file in `06-Knowledge/`:
1. Add `[[wikilinks]]` to all related entities mentioned in the file
2. In each linked entity's file, add a backlink under a `## Mentions` or `## Related` section
3. Log the new connection in `06-Knowledge/_ConnectionLog.md`

### Step 4: Decision Detection

If Dan made a choice (explicit or implicit):
1. Create a decision record in `06-Knowledge/Decisions/` using the template
2. Include context, options considered, rationale, and any consequences observed
3. Link to related entities and previous decisions
4. If this supersedes an earlier decision, update the old record's `superseded_by` field

### Step 5: Belief Check

If Dan expressed an opinion, worldview statement, or assumption:
1. Search `06-Knowledge/Beliefs/` for an existing belief on this topic
2. If found and consistent → increment `evidence_for`, update `last_tested`
3. If found and contradictory → add to `evidence_against`, adjust confidence, flag for Dan
4. If new → create a belief record with initial confidence

### Step 6: Learning Extraction

If Dan learned something or an insight emerged:
1. Create a learning record in `06-Knowledge/Learnings/` using the template
2. Categorise by source (experience, conversation, reading, observation) and domain

### Step 7: Pattern Check

If a theme, behaviour, or preference appeared:
1. Search `06-Knowledge/Patterns/` for existing patterns
2. If match → increment `occurrences`, update `last_seen`, add reference
3. If new but seems recurring (appeared 2+ times across sessions) → create a new pattern with `confidence: emerging`

### Step 8: Personal Model Check

If the conversation reveals something about Dan's values, decision-making style, communication preferences, or recurring interests:
1. Update the relevant file in `07-PersonalModel/`
2. Log the change in `07-PersonalModel/_Changelog.md` with date, what changed, and what triggered it

### Step 9: Contradiction Detection

If new information conflicts with a stored belief or decision:
1. **Do NOT auto-resolve** — Dan decides which to keep
2. Add the contradiction to the relevant belief's `evidence_against`
3. Surface it to Dan: "This seems to contradict your belief that [X] — want to revisit?"
4. If Dan resolves it, update the belief/decision accordingly

---

## Proactive Retrieval

When Dan mentions a topic, **before responding**, search for related knowledge:

### Triggers

- A **person** is mentioned who has an entity file → surface their context
- A **topic** matches an active pattern → mention the pattern and its frequency
- New information **contradicts** an existing belief → flag the tension
- A **decision** is being revisited that has a decision record → surface the original rationale
- A **theme** from `07-PersonalModel/Themes.md` recurs → note the recurrence

### Format

Surface connections naturally, not as system output:
- "You talked about this with [person] on [date] — they suggested [X]"
- "This connects to your decision on [date] to [Y]"
- "This is the third time this month [theme] has come up"

---

## Cron Routines

### 1. Morning Briefing — 07:00 AEST Daily

**Purpose:** Start the day with context and priorities.

**Steps:**
1. Read `BrainIndex.md` and `MEMORY.md`
2. Read `00-Tasks/Tasks.md` for current tasks
3. Check today's calendar (Google Calendar MCP)
4. Scan overnight Slack/email for urgent items
5. Check Trello for overdue or due-today cards
6. Generate briefing and send via Telegram

**Output format:**
```markdown
## Morning Briefing — YYYY-MM-DD

### Today's Schedule
- [Calendar events]

### Priority Tasks
- [From Tasks.md, sorted by priority]

### Overnight Activity
- [Slack mentions, emails, Trello updates]

### Focus Recommendation
- [1-2 sentence suggestion based on patterns]
```

### 2. Data Capture — 12:00 and 18:00 AEST Daily

**Purpose:** Pull data from all sources into the daily log.

**Steps:**
1. Poll Trello API for board changes since last capture
2. Scan Slack for messages in key channels / mentions
3. Check Gmail for new flagged/starred emails
4. Check Fireflies for any new meeting transcripts
5. Append structured summaries to `01-Daily/YYYY-MM-DD.md`

**Output format per source:**
```markdown
### [Source] — HH:MM
- [Bullet summary of activity]
- Entities mentioned: [[entity-name]]
- Decisions made: [if any]
- Action items: [if any]
```

### 3. Evening Synthesis — 21:00 AEST Daily

**Purpose:** Process the day's raw data into structured knowledge.

**Steps:**
1. Read today's daily log (`01-Daily/YYYY-MM-DD.md`)
2. Run the full Connection Protocol (Steps 1-9 above) against today's data
3. Extract and file:
   - **Entities** → `06-Knowledge/Entities/`
   - **Decisions** → `06-Knowledge/Decisions/YYYY-MM-DD-topic.md`
   - **Beliefs** → `06-Knowledge/Beliefs/`
   - **Learnings** → `06-Knowledge/Learnings/topic.md`
   - **Patterns** → `06-Knowledge/Patterns/`
   - **Threads** → `06-Knowledge/Threads/topic.md`
4. Update `06-Knowledge/_Index.md` with new entries
5. Update `06-Knowledge/_ConnectionLog.md` with new relationships
6. Update `MEMORY.md` "Recent Activity" section (remove entries older than 7 days)
7. If personal insights detected, update relevant `07-PersonalModel/` file and log in `_Changelog.md`
8. Git commit: `daily synthesis: YYYY-MM-DD` and push

### 4. Weekly Review — 20:00 AEST Sunday

**Purpose:** Synthesise the week, detect patterns, update themes.

**Steps:**
1. Read all daily logs from the past 7 days
2. Read `00-Tasks/Tasks.md` for completed/outstanding items
3. **Pattern Detection:**
   - Identify themes that appeared 3+ times this week
   - Check `06-Knowledge/Patterns/` for existing patterns → increment or create
   - Upgrade patterns with 5+ occurrences to `confidence: established`
4. **Belief Audit:**
   - For each active belief in `06-Knowledge/Beliefs/`, check this week's events
   - Supporting evidence → add to `evidence_for`, bump confidence
   - Contradicting evidence → add to `evidence_against`, lower confidence
   - Not tested in 30+ days → flag for review
5. **Personal Model Update:**
   - Update `07-PersonalModel/Themes.md` with new/dormant themes
   - Check `07-PersonalModel/DecisionFrameworks.md` for new decision patterns
   - Log all changes in `07-PersonalModel/_Changelog.md`
6. **Connection Review:**
   - Review `06-Knowledge/_ConnectionLog.md` for this week
   - Identify 3-5 most significant cross-references
   - Surface unsurfaced connections to Dan
7. Write weekly review to `02-Weekly/YYYY-MM-DD.md`
8. Update `MEMORY.md` with week summary
9. Send Telegram summary with insights and next week's priorities
10. Git commit: `weekly synthesis: YYYY-WNN` and push

**Weekly review template:**
```markdown
# Week of YYYY-MM-DD

## Accomplishments
- [Completed items]

## Key Decisions
- [Links to decision records]

## Patterns Observed
- [New or reinforced patterns]

## Weekly Connections
- [3-5 most significant cross-references discovered]

## Belief Updates
- [Beliefs that gained or lost confidence]

## Open Threads
- [Unresolved questions or ongoing topics]

## Next Week Priorities
- [Suggested focus areas]

## Personal Notes
- [Energy levels, mood patterns, insights]
```

### 5. Monthly Consolidation — 1st of Month, 10:00 AEST

**Purpose:** Deep clean, merge, archive, and rebuild.

**Steps:**
1. **Knowledge Consolidation:**
   - Scan `06-Knowledge/Entities/` for duplicates or near-duplicates → merge
   - Identify stale entities (not updated in 60+ days) → propose archival
   - Identify beliefs with confidence below 0.3 → archive with note
   - Promote established learnings (90+ days, still referenced) → Pattern
2. **Personal Model Review:**
   - Read all 4 weekly reviews from the month
   - Assess: Have Dan's values shifted? New priorities emerged?
   - Update `07-PersonalModel/Identity.md` if values ranking changed
   - Update `07-PersonalModel/DecisionFrameworks.md` with new heuristics
3. **Goal Progress:**
   - Review active projects in `03-Projects/`
   - Assess progress against stated goals
   - Note any goal drift
4. **Generate Pattern Report** → `06-Knowledge/Patterns/YYYY-MM-pattern-report.md`
5. **Archive Maintenance:**
   - Daily logs older than 30 days → `08-Archive/Daily/`
   - Superseded decisions (30+ days) → `08-Archive/Knowledge/Decisions/`
   - Resolved threads → `08-Archive/Knowledge/Threads/`
   - Add `archive_date` and `archive_reason` to frontmatter
   - Keep `[[wikilinks]]` intact
6. **Rebuild indexes:**
   - Full rebuild of `06-Knowledge/_Index.md`
   - Prune `_ConnectionLog.md` (remove entries where both entities archived)
   - Rebuild MCP search index
7. Write monthly summary to `02-Weekly/YYYY-MM-monthly.md`
8. Git commit: `monthly synthesis: YYYY-MM` and push

### 6. Quarterly Review — 1st of Jan/Apr/Jul/Oct, 20:00 AEST

**Purpose:** "State of Dan" trajectory analysis.

**Steps:**
1. Read all 3 monthly pattern reports from the quarter
2. **Generate "State of Dan" report** covering:
   - Quarter narrative (what happened, what changed, what emerged)
   - Values evolution (compare Identity.md to start-of-quarter)
   - Decision quality (which held up, which revised)
   - Pattern trajectory (strengthened, faded, emerged)
   - Knowledge growth stats (entities added, decisions logged, beliefs updated)
   - Unresolved contradictions and tensions
   - Predictions for next quarter
   - Recommended focus areas
3. **Major Personal Model Revision:**
   - Full review and rewrite of Identity.md if warranted
   - Archive pre-revision version to `08-Archive/PersonalModel/` with date
4. **Deep Archive:**
   - Entities not referenced in 90+ days → archive
   - Beliefs not tested in 90+ days → archive
   - Patterns still `emerging` after 90 days → archive
5. **Knowledge Graph Audit:**
   - Check for orphaned entities (no incoming links)
   - Check for broken `[[wikilinks]]`
   - Identify most-connected entities (hubs)
   - Identify isolated clusters needing connections
6. Save report to `02-Weekly/YYYY-QN-state-of-dan.md`
7. Git commit: `quarterly synthesis: QN YYYY` and push

---

## Schemas

Standard YAML frontmatter for all entity types in `06-Knowledge/`.

### Person
```yaml
---
type: person
name: Full Name
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
context: How Dan knows them
role: Their professional role
org: Their organisation
tags: []
related: []
---
```

### Company
```yaml
---
type: company
name: Company Name
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
industry: Industry/sector
relationship: customer | partner | competitor | employer
tags: []
related: []
---
```

### Tool / Technology
```yaml
---
type: tool
name: Tool Name
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
domain: orchestration | AI | communication | etc.
status: active | evaluating | deprecated
tags: []
related: []
---
```

### Concept
```yaml
---
type: concept
name: Concept Name
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
domain: business | technical | personal | philosophical
tags: []
related: []
---
```

### Decision
```yaml
---
type: decision
date: YYYY-MM-DD
status: active | superseded | reversed
confidence: high | medium | low
related_project: Project name or null
tags: []
supersedes: null
superseded_by: null
---
```
Sections: `## Context`, `## Options Considered`, `## Decision`, `## Rationale`, `## Consequences`, `## Related`

### Belief
```yaml
---
type: belief
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
confidence: 0.0-1.0
domain: business | personal | technical | philosophical
evidence_for: []
evidence_against: []
last_tested: YYYY-MM-DD
---
```
Sections: `## Context`, `## Evidence For`, `## Evidence Against`, `## Status`

### Learning
```yaml
---
type: learning
date: YYYY-MM-DD
source: experience | conversation | reading | observation
domain: technical | business | personal | interpersonal
tags: []
related: []
---
```
Sections: `## What Happened`, `## Lesson`, `## Application`

### Pattern
```yaml
---
type: pattern
first_detected: YYYY-MM-DD
last_seen: YYYY-MM-DD
occurrences: 0
confidence: emerging | established | strong
tags: []
related: []
---
```
Sections: `## Observations`, `## Significance`, `## References`

### Thread
```yaml
---
type: thread
date: YYYY-MM-DD
last_updated: YYYY-MM-DD
participants: []
status: active | resolved | dormant
outcome: null
tags: []
---
```
Sections: `## Context`, `## Key Points`, `## Current Status`, `## Related`

## File Naming Conventions

- **Entities:** `lowercase-hyphenated-name.md` (e.g., `simon-beard.md`)
- **Decisions:** `YYYY-MM-DD-short-description.md` (e.g., `2026-02-25-clickup-orchestration.md`)
- **Beliefs:** `short-descriptive-name.md` (e.g., `marketplace-over-saas.md`)
- **Learnings:** `short-descriptive-name.md` (e.g., `clickup-no-markdown.md`)
- **Patterns:** `short-descriptive-name.md` (e.g., `action-over-analysis.md`)
- **Threads:** `short-topic.md` (e.g., `agent-switching-telegram.md`)

---

## Connection Relationship Types

| Type | Meaning | Example |
|------|---------|---------|
| `founder_of` | Person founded company | Dan → CSTMR |
| `advises` | Person advises entity | Gabe → CSTMR |
| `works_with` | Collaboration | Dan → Josh |
| `uses` | Entity uses tool | CSTMR → OpenRouter |
| `decided` | Person made decision | Dan → use-clickup |
| `superseded_by` | Decision replaced | list-assignment → google-workspace |
| `enables` | Entity enables another | ClickUp → agent-hierarchy |
| `validates` | Evidence supports | daily-synthesis → knowledge-synthesis-value |
| `blocks` | Entity blocks another | — |
| `led_to` | Causal chain | cognitive-architecture → maintain-cognitive-architecture |

---

## MCP Server: secondbrain-memory

Located at `99-System/mcp-servers/secondbrain-memory/`.

**Tools available (when deployed):**

| Tool | Purpose |
|------|---------|
| `search_memory` | Semantic search across all knowledge |
| `get_recent_context` | Load recent daily logs + MEMORY.md |
| `get_entity` | Direct lookup of a person/company/tool |
| `get_decisions` | Search past decisions with rationale |
| `get_personal_model` | Retrieve identity, preferences, frameworks |
| `rebuild_index` | Incrementally rebuild search index |

**Setup:** See `99-System/mcp-servers/secondbrain-memory/README.md` for mcporter configuration.

**All agents should call `get_recent_context` at the start of every session** to load context before responding.

---

## Rules

1. **Never modify `00-Tasks/Tasks.md` without explicit user request**
2. **Never delete knowledge** — always archive to `08-Archive/` with metadata preserved
3. **Always use `[[wikilinks]]`** when referencing other SecondBrain files
4. **Always update `_ConnectionLog.md`** when creating new relationships
5. **Always update `_Index.md`** when adding new knowledge entries
6. **Maintain frontmatter** on all knowledge files (type, date, tags, related)
7. **Git commit after synthesis** — push changes so Obsidian can sync
8. **Respect timezone** — all times in AEST/AEDT (Australia/Melbourne)
9. **Surface contradictions** — never auto-resolve, always ask Dan
10. **Refactor, don't append** — update existing files rather than creating new ones

---

## Cron Job Summary

| Job | Schedule (AEST) | Cron Expression | Purpose |
|-----|-----------------|-----------------|---------|
| Morning Briefing | 07:00 daily | `0 7 * * *` | Context + priorities via Telegram |
| Midday Capture | 12:00 daily | `0 12 * * *` | Pull data from all sources |
| Evening Capture | 18:00 daily | `0 18 * * *` | Pull data from all sources |
| Evening Synthesis | 21:00 daily | `0 21 * * *` | Process → structure → connect → commit |
| Weekly Review | Sun 20:00 | `0 20 * * 0` | Patterns + themes + plan |
| Monthly Consolidation | 1st 10:00 | `0 10 1 * *` | Merge + archive + rebuild |
| Quarterly Review | 1st Q 20:00 | `0 20 1 1,4,7,10 *` | State of Dan report |

---

*Last updated: 2026-03-22*
