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
  tool_choice?: unknown
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

function parseUrl(input: RequestInfo | URL): URL | undefined {
  try {
    return new URL(extractUrl(input))
  } catch {
    return undefined
  }
}

function isCopilotEndpoint(url: URL | undefined, pathname: string): boolean {
  return url?.hostname === "api.githubcopilot.com" && url.pathname === pathname
}

function getToolName(tool: ToolEntry): string {
  return tool.function?.name ?? tool.name ?? "(unnamed)"
}

function isToolEntry(value: unknown): value is ToolEntry {
  if (!isObjectRecord(value)) return false
  if (value.name !== undefined && typeof value.name !== "string") return false
  if (value.function === undefined) return true
  return isObjectRecord(value.function) && (value.function.name === undefined || typeof value.function.name === "string")
}

function isBuiltinCopilotTool(tool: ToolEntry): boolean {
  return BUILTIN_TOOLS.has(getToolName(tool))
}

function isPreferredMcpTool(tool: ToolEntry): boolean {
  const name = getToolName(tool)
  return !BUILTIN_TOOLS.has(name) && ALLOWED_TOOL_PREFIXES.some((prefix) => name.startsWith(prefix))
}

function getToolChoiceName(toolChoice: unknown): string | undefined {
  if (!isObjectRecord(toolChoice) || !isObjectRecord(toolChoice.function)) return undefined
  return typeof toolChoice.function.name === "string" ? toolChoice.function.name : undefined
}

function selectCopilotTools(tools: readonly ToolEntry[], pinnedToolName?: string): ToolEntry[] {
  const pinnedTool = pinnedToolName ? tools.find((tool) => getToolName(tool) === pinnedToolName) : undefined
  const remaining = tools.filter((tool) => tool !== pinnedTool)
  const builtins = remaining.filter(isBuiltinCopilotTool)
  const preferredMcp = remaining.filter(isPreferredMcpTool)
  return [...(pinnedTool ? [pinnedTool] : []), ...builtins, ...preferredMcp].slice(0, MAX_COPILOT_TOOLS)
}

const originalFetch = globalThis.fetch.bind(globalThis)

// GitHub Copilot Student (edu) plans return model_picker_enabled: false on /models,
// which causes OpenCode to filter out all Copilot models. Additionally, Copilot
// /chat/completions rejects payloads exceeding 128 tools.
const patchedFetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
  const url = parseUrl(input)
  let requestInput: RequestInfo | URL = input
  let requestInit = init

  if (isCopilotEndpoint(url, "/chat/completions")) {
    try {
      const request = new Request(input, init)
      const parsed: unknown = await request.clone().json()
      if (isObjectRecord(parsed) && Array.isArray(parsed.tools) && parsed.tools.length > MAX_COPILOT_TOOLS) {
        const rawTools = parsed.tools
        const tools = rawTools.filter(isToolEntry)
        if (tools.length !== rawTools.length) {
          console.warn("Copilot plugin found an invalid tool entry; forwarding the request unchanged.")
        } else {
          const payload: ChatCompletionPayload = { ...parsed, tools }
          const filtered = selectCopilotTools(tools, getToolChoiceName(payload.tool_choice))
          const dropped = tools.filter((tool) => !filtered.includes(tool)).map(getToolName)
          if (dropped.length > 0) {
            console.warn(`Copilot plugin dropped ${dropped.length} tool(s) to meet the 128-tool limit: ${dropped.join(", ")}`)
          }
          const headers = new Headers(request.headers)
          headers.delete("content-length")
          requestInput = new Request(request.url, {
            method: request.method,
            headers,
            body: JSON.stringify({ ...payload, tools: filtered }),
            signal: request.signal,
            mode: request.mode,
            credentials: request.credentials,
            cache: request.cache,
            redirect: request.redirect,
            referrer: request.referrer,
            referrerPolicy: request.referrerPolicy,
            integrity: request.integrity,
            keepalive: request.keepalive,
          })
          requestInit = undefined
        }
      }
    } catch {
      console.warn("Copilot plugin could not inspect the chat request; forwarding it unchanged.")
    }
  }

  const response = await originalFetch(requestInput, requestInit)
  if (!isCopilotEndpoint(url, "/models") || !response.ok) {
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
      const headers = new Headers(response.headers)
      headers.delete("content-encoding")
      headers.delete("content-length")
      return new Response(JSON.stringify(body), {
        status: response.status,
        statusText: response.statusText,
        headers,
      })
    }
  } catch {
    console.warn("Copilot plugin could not inspect the models response; forwarding it unchanged.")
  }

  return response
}

Object.assign(patchedFetch, originalFetch)
globalThis.fetch = patchedFetch as typeof fetch

export const CopilotStudentModelsPlugin = async (): Promise<Record<string, never>> => ({})
