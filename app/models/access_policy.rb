class AccessPolicy < ApplicationRecord
  belongs_to :project

  validates :name, presence: true
  validates :principal_type, presence: true, inclusion: { in: %w[user team token] }

  scope :enabled, -> { where(enabled: true) }
  scope :for_principal, ->(type, id) { where(principal_type: type, principal_id: id) }

  PERMISSIONS = %w[read write delete admin].freeze

  def matches?(secret, environment, permission)
    return false unless enabled?

    # Check environment
    if environments.any?
      return false unless environments.include?(environment.slug)
    end

    # Check path
    if paths.any?
      return false unless paths.any? { |pattern| File.fnmatch?(pattern, secret.path) }
    end

    # Check permission
    permissions.include?(permission)
  end

  def check_conditions(context)
    return true if conditions.blank?

    # Check MFA requirement
    if conditions["require_mfa"]
      return false unless context[:mfa_verified]
    end

    # Check IP allowlist
    if conditions["allowed_ips"].present?
      return false unless ip_allowed?(context[:ip], conditions["allowed_ips"])
    end

    # Check time window
    if conditions["time_window"].present?
      return false unless in_time_window?(conditions["time_window"])
    end

    true
  end

  private

  def ip_allowed?(ip, allowed_ips)
    return true unless ip.present?

    allowed_ips.any? do |allowed|
      if allowed.include?("/")
        IPAddr.new(allowed).include?(ip)
      else
        allowed == ip
      end
    end
  rescue IPAddr::InvalidAddressError
    false
  end

  def in_time_window?(window)
    tz = ActiveSupport::TimeZone[window["timezone"] || "UTC"]
    now = Time.current.in_time_zone(tz)

    now.strftime("%H:%M") >= window["start"] && now.strftime("%H:%M") <= window["end"]
  end
end
