class AccessChecker
  def initialize(project)
    @project = project
  end

  def can_access?(principal, secret, environment, permission: "read")
    policies = find_policies(principal)

    policies.any? do |policy|
      policy_matches?(policy, secret, environment, permission)
    end
  end

  def check_conditions(policy, context)
    policy.check_conditions(context)
  end

  def allowed_secrets(principal, environment, permission: "read")
    policies = find_policies(principal)

    @project.secrets.active.select do |secret|
      policies.any? { |p| policy_matches?(p, secret, environment, permission) }
    end
  end

  private

  def find_policies(principal)
    type, id = case principal
    when AccessToken
                 [ "token", principal.id.to_s ]
    else
                 # For user/team, we'd need Platform integration
                 return []
    end

    AccessPolicy.where(project: @project, enabled: true)
                .where(principal_type: type, principal_id: id)
  end

  def policy_matches?(policy, secret, environment, permission)
    # Check environment
    if policy.environments.any?
      return false unless policy.environments.include?(environment.slug)
    end

    # Check path
    if policy.paths.any?
      return false unless policy.paths.any? { |p| File.fnmatch?(p, secret.path) }
    end

    # Check permission
    policy.permissions.include?(permission)
  end
end
