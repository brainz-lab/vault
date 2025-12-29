require "yaml"
require "erb"

content = File.read(Rails.root.join("test/fixtures/projects.yml"))
rendered = ERB.new(content).result

fixture_data = YAML.safe_load(rendered, permitted_classes: [Date, Time, DateTime])

puts "Fixture data:"
fixture_data.each do |name, attrs|
  puts "  #{name}:"
  attrs.each do |k, v|
    puts "    #{k}: #{v.inspect} (#{v.class})"
  end
end

# Check what columns the table has
puts "\nProject columns:"
Project.columns.each do |col|
  puts "  #{col.name}: #{col.type} (null: #{col.null})"
end

# Try creating a project manually
puts "\nManual create test:"
attrs = fixture_data["acme"].dup
puts "  Attrs: #{attrs.inspect}"
p = Project.new(attrs)
puts "  Before save - platform_project_id: #{p.platform_project_id.inspect}"
if p.valid?
  puts "  Valid!"
else
  puts "  Invalid: #{p.errors.full_messages}"
end
