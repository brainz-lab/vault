module Api
  module V1
    class AuditLogsController < BaseController
      # GET /api/v1/audit_logs
      def index
        require_permission!("read")

        logs = current_project.audit_logs.order(created_at: :desc)

        # Filter by action
        logs = logs.where(action: params[:action]) if params[:action].present?

        # Filter by secret
        if params[:secret_key].present?
          secret = current_project.secrets.find_by(key: params[:secret_key])
          logs = logs.where(secret: secret) if secret
        end

        # Filter by actor
        logs = logs.where(actor_id: params[:actor_id]) if params[:actor_id].present?

        # Filter by date range
        logs = logs.where("created_at >= ?", Time.parse(params[:from])) if params[:from].present?
        logs = logs.where("created_at <= ?", Time.parse(params[:to])) if params[:to].present?

        # Pagination
        page = (params[:page] || 1).to_i
        per_page = [(params[:per_page] || 50).to_i, 100].min
        total = logs.count
        logs = logs.offset((page - 1) * per_page).limit(per_page)

        render json: {
          logs: logs.map { |l| log_json(l) },
          pagination: {
            page: page,
            per_page: per_page,
            total: total,
            pages: (total.to_f / per_page).ceil
          }
        }
      end

      # GET /api/v1/audit_logs/secret/:key
      def for_secret
        require_permission!("read")

        secret = current_project.secrets.find_by!(key: params[:key])
        logs = secret.audit_logs.order(created_at: :desc).limit(100)

        render json: {
          secret: secret.key,
          logs: logs.map { |l| log_json(l) }
        }
      end

      private

      def log_json(log)
        {
          id: log.id,
          action: log.action,
          secret_key: log.secret&.key,
          actor_type: log.actor_type,
          actor_name: log.actor_name,
          ip_address: log.ip_address,
          details: log.details,
          created_at: log.created_at
        }
      end
    end
  end
end
