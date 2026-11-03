import { afterAll, expect, spyOn, test } from "bun:test"

let capturedRequestBody = ""
let capturedRequestHeaders: Headers | undefined
let nextResponse: Response | undefined
const originalFetch = globalThis.fetch
const originalWarn = spyOn(console, "warn").mockImplementation(() => {})

globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
  const request = new Request(input, init)
  capturedRequestBody = await request.clone().text()
  capturedRequestHeaders = request.headers
  const response = nextResponse
  nextResponse = undefined
  return response ?? new Response(null, { status: 204 })
}

await import("../dotfiles/opencode/plugins/copilot-student-models.ts")
afterAll(() => {
  globalThis.fetch = originalFetch
  originalWarn.mockRestore()
})

function context7Tools(): Array<{ type: string; function: { name: string } }> {
  const tools = Array.from({ length: 140 }, (_, index) => ({
    type: "function",
    function: { name: `context7_tool_${index}` },
  }))
  tools.push({ type: "function", function: { name: "StructuredOutput" } })
  return tools
}

function capturedTools(): unknown[] {
  const parsed: unknown = JSON.parse(capturedRequestBody)
  if (typeof parsed !== "object" || parsed === null || !("tools" in parsed) || !Array.isArray(parsed.tools)) {
    throw new Error("Expected the Copilot request to contain tools")
  }
  const tools: unknown[] = parsed.tools
  return tools
}

function getToolName(tool: unknown): string | undefined {
  if (typeof tool !== "object" || tool === null || !("function" in tool)) return undefined
  const callable = tool.function
  if (typeof callable !== "object" || callable === null || !("name" in callable)) return undefined
  return typeof callable.name === "string" ? callable.name : undefined
}

test("keeps StructuredOutput ahead of Copilot's 128-tool limit", async () => {
  originalWarn.mockClear()
  const tools = context7Tools()
  const body = JSON.stringify({ tools })
  await globalThis.fetch("https://api.githubcopilot.com/chat/completions", {
    method: "POST",
    headers: { "content-length": String(body.length) },
    body,
  })

  const names = capturedTools().map(getToolName)
  expect(names).toHaveLength(128)
  expect(names[0]).toBe("StructuredOutput")
  expect(names).toContain("StructuredOutput")
  expect(capturedRequestHeaders?.has("content-length")).toBe(false)
  expect(originalWarn).toHaveBeenCalled()
})

test("retains a tool pinned by tool_choice before truncating", async () => {
  const tools = context7Tools()
  await globalThis.fetch(
    new Request("https://api.githubcopilot.com/chat/completions", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        tools,
        tool_choice: { type: "function", function: { name: "context7_tool_139" } },
      }),
    }),
  )

  const names = capturedTools().map(getToolName)
  expect(names).toHaveLength(128)
  expect(names[0]).toBe("context7_tool_139")
  expect(names).toContain("StructuredOutput")
})

test("does not rewrite a URL that only mentions the Copilot host in its query", async () => {
  const tools = context7Tools()
  await globalThis.fetch("https://example.test/chat/completions?target=api.githubcopilot.com", {
    method: "POST",
    body: JSON.stringify({ tools }),
  })

  expect(capturedTools()).toHaveLength(141)
})

test("warns and forwards malformed Copilot request JSON unchanged", async () => {
  originalWarn.mockClear()
  await globalThis.fetch("https://api.githubcopilot.com/chat/completions", {
    method: "POST",
    body: "not-json",
  })

  expect(capturedRequestBody).toBe("not-json")
  expect(originalWarn).toHaveBeenCalled()
})

test("removes stale transport headers from rewritten Copilot model responses", async () => {
  nextResponse = new Response(JSON.stringify({ data: [{ model_picker_enabled: false, policy: { state: "enabled" } }] }), {
    headers: {
      "content-type": "application/json",
      "content-encoding": "identity",
      "content-length": "1",
    },
  })

  const response = await globalThis.fetch("https://api.githubcopilot.com/models")
  expect(response.headers.has("content-encoding")).toBe(false)
  expect(response.headers.has("content-length")).toBe(false)
  expect(await response.json()).toEqual({ data: [{ model_picker_enabled: true, policy: { state: "enabled" } }] })
})
