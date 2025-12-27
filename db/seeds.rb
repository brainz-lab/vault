# Create a development project if none exists
if Rails.env.development? && Project.count.zero?
  Project.create!(
    platform_project_id: "dev_project",
    name: "Development Project"
  )
  puts "Created development project"
end
