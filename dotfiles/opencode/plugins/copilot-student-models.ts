const MAX_COPILOT_TOOLS = 128

const ALLOWED_TOOL_PREFIXES = ["codebase-memory-mcp_", "context7_"] as const

const BUILTIN_TOOLS = new Set([
  "StructuredOutput",
  "bash",
  "read",
  "glob",
  "grep",
  "edit",
  "write",
  "patch",
  "apply_patch",
  "multiedit",
  "ls",
  "list",
  "task",
  "webfetch",
  "websearch",
  "codesearch",
  "todowrite",
  "todoread",
  "question",
  "skill",
  "batch",
  "plan_enter",
  "plan_exit",
])

interface CopilotModelPolicy {
  readonly state?: string
}

interface CopilotModelEntry {
  model_picker_enabled?: boolean
  readonly policy?: CopilotModelPolicy
}

interface CopilotModelsResponse {
  readonly data?: CopilotModelEntry[]
}

interface ToolEntry {
  readonly name?: string
  readonly function?: {
    readonly name?: string
  }
}

interface ChatCompletionPayload {
  tools?: ToolEntry[]
  [key: string]: unknown
}

function isObjectRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}

function extractUrl(input: RequestInfo | URL): string {
  if (typeof input === "string") {
    return input
  }
  if (input instanceof URL) {
    return input.href
  }
  return input.url
}

function isBuiltinCopilotTool(tool: ToolEntry): boolean {
  const name = tool.function?.name ?? tool.name ?? ""
  return BUILTIN_TOOLS.has(name)
}

function isPreferredMcpTool(tool: ToolEntry): boolean {
  const name = tool.function?.name ?? tool.name ?? ""
  return !BUILTIN_TOOLS.has(name) && ALLOWED_TOOL_PREFIXES.some((prefix) => name.startsWith(prefix))
}

function selectCopilotTools(tools: readonly ToolEntry[]): ToolEntry[] {
  const builtins = tools.filter(isBuiltinCopilotTool)
  const preferredMcp = tools.filter(isPreferredMcpTool)
  return [...builtins, ...preferredMcp].slice(0, MAX_COPILOT_TOOLS)
}

const originalFetch = globalThis.fetch

// GitHub Copilot Student (edu) plans return model_picker_enabled: false on /models,
// which causes OpenCode to filter out all Copilot models. Additionally, Copilot
// /chat/completions rejects payloads exceeding 128 tools.
const patchedFetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
  const url = extractUrl(input)
  let requestInit = init

  if (url.includes("githubcopilot.com") && typeof requestInit?.body === "string") {
    try {
      const parsed: unknown = JSON.parse(requestInit.body)
      if (isObjectRecord(parsed) && Array.isArray(parsed.tools) && parsed.tools.length > MAX_COPILOT_TOOLS) {
        const payload = parsed as ChatCompletionPayload
        const filtered = selectCopilotTools(payload.tools ?? [])
        requestInit = {
          ...requestInit,
          body: JSON.stringify({ ...payload, tools: filtered }),
        }
      }
    } catch {
      // Preserve original body when request payload is not JSON
    }
  }

  const response = await originalFetch(input, requestInit)
  if (!url.includes("githubcopilot.com/models") || !response.ok) {
    return response
  }

  try {
    const parsed: unknown = await response.clone().json()
    if (isObjectRecord(parsed) && Array.isArray(parsed.data)) {
      const body = parsed as CopilotModelsResponse
      for (const model of body.data ?? []) {
        if (isObjectRecord(model) && model.policy?.state !== "disabled") {
          model.model_picker_enabled = true
        }
      }
      return new Response(JSON.stringify(body), {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers,
      })
    }
  } catch {
    // Fall back to original response if JSON parsing fails
  }

  return response
}

Object.assign(patchedFetch, originalFetch)
globalThis.fetch = patchedFetch as typeof fetch

export const CopilotStudentModelsPlugin = async (): Promise<Record<string, never>> => ({})
