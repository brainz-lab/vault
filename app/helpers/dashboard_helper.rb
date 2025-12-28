module DashboardHelper
  def action_badge_class(action)
    case action
    when /create/
      "badge-green"
    when /update/, /set/
      "badge-blue"
    when /delete/, /archive/, /revoke/
      "badge-red"
    when /read/, /get/, /list/, /export/
      "badge-gray"
    when /rollback/
      "badge-yellow"
    when /import/
      "badge-orange"
    else
      "badge-gray"
    end
  end

  def provider_badge_class(provider)
    case provider.to_s.downcase
    when "openai"
      "bg-green-100 text-green-700"
    when "anthropic"
      "bg-orange-100 text-orange-700"
    when "google"
      "bg-blue-100 text-blue-700"
    when "azure"
      "bg-sky-100 text-sky-700"
    when "cohere"
      "bg-purple-100 text-purple-700"
    when "mistral"
      "bg-indigo-100 text-indigo-700"
    when "groq"
      "bg-yellow-100 text-yellow-700"
    when "replicate"
      "bg-pink-100 text-pink-700"
    when "huggingface"
      "bg-amber-100 text-amber-700"
    else
      "bg-stone-100 text-stone-700"
    end
  end
end
