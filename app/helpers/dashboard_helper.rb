module DashboardHelper
  def action_badge_class(action)
    case action
    when /create/
      "bg-green-100 text-green-800"
    when /update/, /set/
      "bg-blue-100 text-blue-800"
    when /delete/, /archive/, /revoke/
      "bg-red-100 text-red-800"
    when /read/, /get/, /list/, /export/
      "bg-gray-100 text-gray-800"
    when /rollback/
      "bg-yellow-100 text-yellow-800"
    when /import/
      "bg-purple-100 text-purple-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end
end
