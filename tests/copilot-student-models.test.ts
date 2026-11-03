import { afterAll, expect, test } from "bun:test"

let capturedRequestBody = ""
const originalFetch = globalThis.fetch

globalThis.fetch = async (_input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
  capturedRequestBody = typeof init?.body === "string" ? init.body : ""
  return new Response(null, { status: 204 })
}

await import("../dotfiles/opencode/plugins/copilot-student-models.ts")
afterAll(() => {
  globalThis.fetch = originalFetch
})

function getToolName(tool: unknown): string | undefined {
  if (typeof tool !== "object" || tool === null || !("function" in tool)) return undefined
  const callable = tool.function
  if (typeof callable !== "object" || callable === null || !("name" in callable)) return undefined
  return typeof callable.name === "string" ? callable.name : undefined
}

test("keeps StructuredOutput ahead of Copilot's 128-tool limit", async () => {
  const tools = Array.from({ length: 140 }, (_, index) => ({
    type: "function",
    function: { name: `context7_tool_${index}` },
  }))
  tools.push({ type: "function", function: { name: "StructuredOutput" } })

  await globalThis.fetch("https://api.githubcopilot.com/chat/completions", {
    method: "POST",
    body: JSON.stringify({ tools }),
  })

  const parsed: unknown = JSON.parse(capturedRequestBody)
  if (typeof parsed !== "object" || parsed === null || !("tools" in parsed) || !Array.isArray(parsed.tools)) {
    throw new Error("Expected the Copilot request to contain tools")
  }

  const parsedTools: unknown[] = parsed.tools
  const names = parsedTools.map(getToolName)
  expect(names).toHaveLength(128)
  expect(names[0]).toBe("StructuredOutput")
  expect(names).toContain("StructuredOutput")
})
