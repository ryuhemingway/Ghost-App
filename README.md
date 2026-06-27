# Ghost

Ghost is a macOS menu-bar AI workspace for connecting local models, cloud providers, local agents, document retrieval, native actions, and verified file tools in one glass-native interface.

It can run fast Direct API calls, hand deeper work to a Ghost/Hermes-style agent, index your local files into a RAG store, create and convert common documents, read safe workspace context, search the web, create reminders and calendar events, and show a transparent activity trail for what happened.

## Highlights

- **Menu-bar Mac app:** Ghost runs as a macOS accessory app and opens from the menu bar. `Option + Space` toggles the panel.
- **Two execution engines:** Direct API for fast provider calls, Ghost Agent for multi-turn local work with tools, approvals, and shell/coding workflows.
- **Provider support:** LM Studio, Ollama, Claude, Gemini, and DeepSeek v4.
- **Local-provider isolation:** LM Studio and Ollama are forced through Ghost's managed Direct API tool loop so a local-model prompt does not accidentally launch a cloud-backed agent.
- **Capability harness:** File, folder, document, conversion, Finder, and RAG actions are path-normalized, permission-checked, executed, and verified by Ghost.
- **Local RAG:** Index supported local documents into SQLite, query cited chunks, sync folders, reindex, remove documents, open sources, and clear only the index.
- **Native actions:** Create reminders, create/query calendar events, dictate prompts, search the web, and run restricted read-only shell checks.
- **Two surfaces:** Ghost Glass for quick assistant work and Ghost Code for wider terminal-style traces.

## Requirements

- macOS 14 or newer
- Xcode command line tools or Xcode with Swift 6.1 support
- Optional: LM Studio at `http://localhost:1234/v1`
- Optional: Ollama at `http://localhost:11434`
- Optional: API keys for Claude, Gemini, or DeepSeek
- Optional: a compatible local agent binary, such as `ghost` or `hermes`

Install Xcode command line tools if needed:

```bash
xcode-select --install
```

## Build And Run

Clone the repo:

```bash
git clone https://github.com/ryuhemingway/Ghost-App.git
cd Ghost-App
```

Build the Swift package:

```bash
swift build
```

Build and launch the `.app` bundle:

```bash
./script/build_and_run.sh
```

Verify the app launches:

```bash
./script/build_and_run.sh --verify
```

The script creates `dist/Ghost.app`, writes the app `Info.plist`, copies SwiftPM resources, and launches Ghost as a menu-bar accessory app.

## Provider Setup

Open Ghost, then use Settings to choose a provider, model, engine, effort level, and working directory.

### LM Studio

1. Start LM Studio's local server.
2. Confirm the server is available at `http://localhost:1234/v1/models`.
3. In Ghost, choose **LM Studio**.
4. Refresh local models and select a non-embedding chat model.

Ghost uses:

```text
OPENAI_BASE_URL=http://localhost:1234/v1
OPENAI_API_KEY=lm-studio
```

### Ollama

1. Start Ollama.
2. Pull or create a chat model.
3. In Ghost, choose **Ollama**.
4. Set the Ollama base URL if you are not using the default `http://localhost:11434`.

Ghost calls Ollama through its OpenAI-compatible endpoint:

```text
http://localhost:11434/v1/chat/completions
```

### Claude, Gemini, And DeepSeek

Add API keys in Settings > API Keys. Ghost stores provider secrets in:

```text
~/.ghost/.env
```

Supported environment keys:

```text
ANTHROPIC_API_KEY
GEMINI_API_KEY
GOOGLE_API_KEY
DEEPSEEK_API_KEY
```

Direct API mode requires the selected provider's key. Agent mode passes only the key family required by the selected provider.

## Connect Your Agent

Ghost can launch a compatible local agent when the **Ghost Agent** execution engine is selected.

Supported agent kinds:

| Agent kind | Default executable |
| --- | --- |
| Ghost Agent | `~/.local/bin/ghost` |
| Hermes Agent | `~/.local/bin/hermes` |

For Ghost Agent, Ghost runs:

```bash
ghost chat -q "<prompt>" -Q --provider <provider> -m <model> --max-turns <turns>
```

For Hermes Agent, Ghost runs:

```bash
hermes chat -q "<prompt>" -Q -m <provider>/<model>
```

Approval modes map to agent flags:

| Ghost approval mode | Agent behavior |
| --- | --- |
| Ask | Default agent approval flow |
| Safe | Adds `--accept-hooks` for Ghost Agent |
| Max | Adds `--yolo` |

If you use custom toolsets, Ghost forwards them with:

```bash
--toolsets <toolsets>
```

Ghost also reads project instructions from the working directory. If an `AGENTS.md` or `GHOST.md` file exists, Ghost includes up to 24,000 characters from it in the agent prompt context.

### Provider Isolation

Local providers are deliberately isolated. If LM Studio or Ollama is selected, Ghost blocks Agent mode and uses the Direct API tool loop instead. This prevents local-model prompts from accidentally launching a previously configured cloud-backed agent.

For local models, Ghost sets local endpoint variables such as:

```text
GHOST_LOCAL_MODEL_PROVIDER
GHOST_LOCAL_MODEL
OPENAI_BASE_URL
OPENAI_API_KEY
LMSTUDIO_HOST
OLLAMA_HOST
```

Cloud provider keys that do not belong to the selected provider are scrubbed from the agent environment before launch.

## RAG System

Ghost RAG is a local SQLite-backed retrieval system. It extracts text from allowed files, chunks the text, stores document metadata and chunks, and lets the model query cited source context.

Default database path:

```text
~/Library/Application Support/Ghost/rag/ghost_rag.sqlite
```

Allowed source roots:

- Current workspace
- `~/Ghost Outputs`
- `~/Desktop`
- `~/Downloads`
- `~/Documents`
- iCloud Books documents

Supported file types:

```text
txt, md, markdown, html, htm, pdf, docx, epub, csv, json, rtf,
swift, py, js, ts, tsx, jsx, java, cpp, c, h, hpp, m, mm, sql,
xml, yaml, yml, toml, log
```

RAG tools:

| Tool | What it does |
| --- | --- |
| `ghost_rag_ingest_file` | Index one supported local file |
| `ghost_rag_ingest_folder` | Index files from a folder |
| `ghost_rag_sync_folder` | Incrementally sync a folder and optionally remove missing sources |
| `ghost_rag_remove_document` | Remove one document from the index without deleting the source |
| `ghost_rag_reindex` | Re-extract and reindex current documents |
| `ghost_rag_query` | Retrieve cited chunks for grounded answers |
| `ghost_rag_search_chunks` | Search indexed chunks and return excerpts |
| `ghost_rag_open_source` | Open a cited source document |
| `ghost_rag_status` | Return database path, document count, and chunk count |
| `ghost_rag_clear_index` | Clear the local index without deleting source files |

Example prompts:

```text
Index my Documents/Research folder for RAG.
What does the onboarding PDF say about setup? Cite the source chunks.
Sync the project docs folder and remove missing files from the index.
Show Ghost RAG status.
```

## Capability Harness

The capability harness is Ghost's verification layer. Models can request tools, but Ghost performs the real work and returns structured results.

Implemented harness capabilities include:

- Directory listing, file info, file reading, and filename/path search
- File creation and updates
- Folder creation, copy, move, trash delete, open file, and reveal in Finder
- Markdown, HTML, TXT, CSV, JSON, PDF, DOCX, PPTX, and XLSX creation
- Limited file conversion to PDF, DOCX, HTML, TXT, or Markdown
- RAG ingest, query, sync, status, and source-opening tools
- Web search with citation instructions
- Calendar creation/query, reminders, and read-only command execution

The harness only reads and writes inside allowed roots, blocks sensitive/credential-like paths, validates text formats where required, and reports whether the operation was verified.

## Direct API Tool Loop

Direct API mode calls the selected provider's HTTP API directly. For local OpenAI-compatible providers, Ghost provides a managed tool loop so local models can call Ghost tools without needing a separate agent process.

Local Direct API tools include:

- `ghost_web_search`
- `ghost_search_files`
- `ghost_read_file`
- `ghost_create_file`
- Capability harness file/document tools
- Ghost RAG tools
- `ghost_schedule_reminder`
- `ghost_create_calendar_event`
- `ghost_query_calendar`
- `ghost_run_readonly_command`

Read-only commands are restricted to a safe allowlist, must avoid shell syntax such as pipes and redirects, and are capped by timeout and output limits.

## Development

Run tests:

```bash
swift test
```

Run with logs:

```bash
./script/build_and_run.sh --logs
```

Run with telemetry logs:

```bash
./script/build_and_run.sh --telemetry
```

Debug the app binary:

```bash
./script/build_and_run.sh --debug
```

## Website

The marketing website lives in `docs/` so it can be served by GitHub Pages from the repository's `/docs` folder.

Open locally:

```bash
python3 -m http.server 4173 --directory docs
```

Then visit:

```text
http://localhost:4173
```

## Repository Structure

```text
Sources/Ghost/App              App entry point and menu-bar integration
Sources/Ghost/Views            Ghost Glass and Ghost Code UI
Sources/Ghost/Models           Providers, engines, effort, telemetry, messages
Sources/Ghost/Services         Agent, Direct API, RAG, harness, calendar, reminders
Sources/Ghost/Stores           Conversation state and routing orchestration
Tests/GhostTests               Intent routing, RAG, and harness tests
docs                           GitHub Pages website
script/build_and_run.sh        macOS app bundle build/run helper
```
