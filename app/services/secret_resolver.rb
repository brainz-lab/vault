class SecretResolver
  def initialize(project, environment)
    @project = project
    @environment = environment
  end

  def resolve(path)
    secret = @project.secrets.active.find_by(path: path)
    return nil unless secret

    @environment.resolve_value(secret)
  end

  def resolve_all
    secrets = {}

    @project.secrets.active.find_each do |secret|
      value = @environment.resolve_value(secret)
      secrets[secret.key] = value if value.present?
    end

    secrets
  end

  def resolve_with_references(template)
    # Replace ${SECRET_NAME} with actual values
    template.gsub(/\$\{([A-Z_][A-Z0-9_]*)\}/) do |match|
      key = $1
      secret = @project.secrets.active.find_by(key: key)
      secret ? @environment.resolve_value(secret) : match
    end
  end

  def resolve_for_service(service_name)
    # Get secrets tagged for this service
    @project.secrets
            .active
            .with_tag("service", service_name)
            .each_with_object({}) do |secret, hash|
      value = @environment.resolve_value(secret)
      hash[secret.key] = value if value.present?
    end
  end

  def resolve_by_folder(folder_path)
    folder = @project.secret_folders.find_by(path: folder_path)
    return {} unless folder

    @project.secrets
            .active
            .in_folder(folder)
            .each_with_object({}) do |secret, hash|
      value = @environment.resolve_value(secret)
      hash[secret.key] = value if value.present?
    end
  end
end
