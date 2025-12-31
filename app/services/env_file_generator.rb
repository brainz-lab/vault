class EnvFileGenerator
  def initialize(environment)
    @environment = environment
    @project = environment.project
  end

  def generate(format: :dotenv)
    secrets = SecretResolver.new(@project, @environment).resolve_all

    case format
    when :dotenv
      generate_dotenv(secrets)
    when :json
      secrets.to_json
    when :yaml
      secrets.to_yaml
    when :shell
      generate_shell(secrets)
    else
      raise ArgumentError, "Unknown format: #{format}"
    end
  end

  private

  def generate_dotenv(secrets)
    secrets.map do |key, value|
      escaped_value = escape_dotenv_value(value)
      "#{key}=#{escaped_value}"
    end.join("\n")
  end

  def generate_shell(secrets)
    secrets.map do |key, value|
      escaped_value = Shellwords.escape(value)
      "export #{key}=#{escaped_value}"
    end.join("\n")
  end

  def escape_dotenv_value(value)
    return '""' if value.nil? || value.empty?

    # Check if value needs quoting
    needs_quotes = value.match?(/[\s#"'$\\]/) || value.include?("\n")

    if needs_quotes
      # Double-quote and escape special characters
      escaped = value.gsub("\\", "\\\\").gsub('"', '\\"').gsub("\n", '\\n')
      "\"#{escaped}\""
    else
      value
    end
  end
end
