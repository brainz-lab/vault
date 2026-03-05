module AssistantHelper
  def render_markdown(text)
    return "" if text.blank?
    html = ERB::Util.html_escape(text)
    html = html.gsub(/```(\w*)\n(.*?)```/m) { "<pre><code>#{$2}</code></pre>" }
    html = html.gsub(/`([^`]+)`/, '<code>\1</code>')
    html = html.gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
    html = html.gsub(/\*(.+?)\*/, '<em>\1</em>')
    html = html.gsub(/^### (.+)$/, '<h3>\1</h3>')
    html = html.gsub(/^## (.+)$/, '<h2>\1</h2>')
    html = html.gsub(/^# (.+)$/, '<h1>\1</h1>')
    html = html.gsub(/^---+$/, "<hr>")
    html = html.gsub(/^(\|.+\|)\n(\|[-| :]+\|)\n((?:\|.+\|\n?)+)/m) do
      header_row = $1; body_rows = $3.strip.split("\n")
      headers = header_row.split("|").map(&:strip).reject(&:empty?)
      table = "<table><thead><tr>"
      headers.each { |h| table += "<th>#{h}</th>" }
      table += "</tr></thead><tbody>"
      body_rows.each do |row|
        cells = row.split("|").map(&:strip).reject(&:empty?)
        table += "<tr>"; cells.each { |c| table += "<td>#{c}</td>" }; table += "</tr>"
      end
      table += "</tbody></table>"
    end
    html = html.gsub(/(?:^- .+$\n?)+/m) do |match|
      items = match.strip.split("\n").map { |line| "<li>#{line.sub(/^- /, '')}</li>" }
      "<ul>#{items.join}</ul>"
    end
    html = html.gsub(/(?:^\d+\. .+$\n?)+/m) do |match|
      items = match.strip.split("\n").map { |line| "<li>#{line.sub(/^\d+\. /, '')}</li>" }
      "<ol>#{items.join}</ol>"
    end
    html = html.split(/\n{2,}/).map do |block|
      block = block.strip
      if block.start_with?("<h", "<ul", "<ol", "<pre", "<table", "<hr")
        block
      else
        "<p>#{block.gsub("\n", "<br>")}</p>"
      end
    end.join
    html.html_safe
  end
end
