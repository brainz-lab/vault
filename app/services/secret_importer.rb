class SecretImporter
  def initialize(project, environment)
    @project = project
    @environment = environment
  end

  def import_from_env_file(content, user: nil)
    imported = []
    errors = []

    content.each_line do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")

      if match = line.match(/\A([A-Z][A-Z0-9_]*)=(.*)?\z/)
        key = match[1]
        value = parse_value(match[2])

        begin
          import_secret(key, value, user: user)
          imported << key
        rescue => e
          errors << { key: key, error: e.message }
        end
      end
    end

    { imported: imported, errors: errors }
  end

  def import_from_json(json_content, user: nil)
    data = JSON.parse(json_content)
    imported = []
    errors = []

    data.each do |key, value|
      begin
        import_secret(key.upcase, value.to_s, user: user)
        imported << key
      rescue => e
        errors << { key: key, error: e.message }
      end
    end

    { imported: imported, errors: errors }
  end

  private

  def import_secret(key, value, user: nil)
    secret = @project.secrets.find_or_initialize_by(key: key)

    if secret.new_record?
      secret.save!
    end

    secret.set_value(@environment, value, user: user, note: "Imported")
  end

  def parse_value(raw_value)
    return "" if raw_value.nil?

    # Remove surrounding quotes
    if raw_value.start_with?('"') && raw_value.end_with?('"')
      raw_value[1..-2].gsub('\\n', "\n").gsub('\\"', '"')
    elsif raw_value.start_with?("'") && raw_value.end_with?("'")
      raw_value[1..-2]
    else
      raw_value
    end
  end
end
