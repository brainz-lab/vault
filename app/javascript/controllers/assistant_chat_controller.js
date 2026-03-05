import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "typing", "form", "sendButton"]
  static values = { url: String }

  connect() {
    this.scrollToBottom()
    this.autoResize()
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.send(event)
    }
    // Auto-resize textarea
    this.autoResize()
  }

  autoResize() {
    const input = this.inputTarget
    input.style.height = "auto"
    input.style.height = Math.min(input.scrollHeight, 120) + "px"
  }

  quickPrompt(event) {
    const prompt = event.currentTarget.dataset.prompt
    this.inputTarget.value = prompt
    this.autoResize()
    this.send(event)
  }

  async send(event) {
    event.preventDefault()

    const content = this.inputTarget.value.trim()
    if (!content) return

    // Disable input
    this.inputTarget.value = ""
    this.inputTarget.disabled = true
    this.sendButtonTarget.disabled = true
    this.autoResize()

    // Append user message
    this.appendUserMessage(content)
    this.scrollToBottom()

    // Show typing indicator
    this.typingTarget.style.display = "flex"
    this.scrollToBottom()

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ content: content })
      })

      const data = await response.json()

      // Hide typing indicator
      this.typingTarget.style.display = "none"

      if (data.error) {
        this.appendAssistantMessage("Error: " + data.error)
      } else {
        // Show tool calls if any
        if (data.tool_calls && data.tool_calls.length > 0) {
          data.tool_calls.forEach(tc => {
            if (tc.type === "tool_call" && tc.tool_calls) {
              tc.tool_calls.forEach(call => {
                this.appendToolCall(call.name)
              })
            }
          })
        }

        // Show assistant response
        if (data.content) {
          this.appendAssistantMessage(data.content)
        }
      }
    } catch (error) {
      this.typingTarget.style.display = "none"
      this.appendAssistantMessage("Connection error. Please try again.")
    }

    // Re-enable input
    this.inputTarget.disabled = false
    this.sendButtonTarget.disabled = false
    this.inputTarget.focus()
    this.scrollToBottom()
  }

  appendUserMessage(content) {
    const div = document.createElement("div")
    div.className = "flex justify-end"
    div.innerHTML = `
      <div class="max-w-[75%] rounded-2xl rounded-br-md px-4 py-2.5" style="background-color: var(--dm-brand); color: white;">
        <p class="text-sm whitespace-pre-wrap">${this.escapeHtml(content)}</p>
      </div>
    `
    this.messagesTarget.insertBefore(div, this.typingTarget)
  }

  appendAssistantMessage(content) {
    const div = document.createElement("div")
    div.className = "flex justify-start"
    div.innerHTML = `
      <div class="max-w-[85%]">
        <div class="rounded-2xl rounded-bl-md px-4 py-2.5" style="background-color: var(--dm-surface-light);">
          <div class="text-sm prose prose-sm max-w-none assistant-markdown" style="color: var(--dm-text);">${this.renderMarkdown(content)}</div>
        </div>
      </div>
    `
    this.messagesTarget.insertBefore(div, this.typingTarget)
  }

  appendToolCall(toolName) {
    const div = document.createElement("div")
    div.className = "flex justify-start"
    div.innerHTML = `
      <div class="max-w-[85%]">
        <div class="flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs" style="background-color: var(--dm-info-bg); color: var(--dm-info-text);">
          <svg class="w-3.5 h-3.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
          <span>Used tool: <strong>${this.escapeHtml(toolName)}</strong></span>
        </div>
      </div>
    `
    this.messagesTarget.insertBefore(div, this.typingTarget)
  }

  scrollToBottom() {
    requestAnimationFrame(() => {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    })
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  renderMarkdown(text) {
    if (!text) return ""
    let html = this.escapeHtml(text)
    html = html.replace(/```(\w*)\n([\s\S]*?)```/g, '<pre><code>$2</code></pre>')
    html = html.replace(/`([^`]+)`/g, '<code>$1</code>')
    html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    html = html.replace(/\*(.+?)\*/g, '<em>$1</em>')
    html = html.replace(/^### (.+)$/gm, '<h3>$1</h3>')
    html = html.replace(/^## (.+)$/gm, '<h2>$1</h2>')
    html = html.replace(/^# (.+)$/gm, '<h1>$1</h1>')
    html = html.replace(/^---+$/gm, '<hr>')
    html = html.replace(/^(\|.+\|)\n(\|[-| :]+\|)\n((?:\|.+\|\n?)+)/gm, (match, headerRow, sepRow, bodyStr) => {
      const headers = headerRow.split("|").map(h => h.trim()).filter(h => h)
      const bodyRows = bodyStr.trim().split("\n")
      let table = "<table><thead><tr>"
      headers.forEach(h => table += `<th>${h}</th>`)
      table += "</tr></thead><tbody>"
      bodyRows.forEach(row => {
        const cells = row.split("|").map(c => c.trim()).filter(c => c)
        table += "<tr>"
        cells.forEach(c => table += `<td>${c}</td>`)
        table += "</tr>"
      })
      table += "</tbody></table>"
      return table
    })
    html = html.replace(/(?:^- .+$\n?)+/gm, match => {
      const items = match.trim().split("\n").map(line => `<li>${line.replace(/^- /, '')}</li>`)
      return `<ul>${items.join('')}</ul>`
    })
    html = html.replace(/(?:^\d+\. .+$\n?)+/gm, match => {
      const items = match.trim().split("\n").map(line => `<li>${line.replace(/^\d+\. /, '')}</li>`)
      return `<ol>${items.join('')}</ol>`
    })
    html = html.split(/\n{2,}/).map(block => {
      block = block.trim()
      if (block.startsWith("<h") || block.startsWith("<ul") || block.startsWith("<ol") || block.startsWith("<pre") || block.startsWith("<table") || block.startsWith("<hr")) {
        return block
      }
      return `<p>${block.replace(/\n/g, "<br>")}</p>`
    }).join("")
    return html
  }
}
