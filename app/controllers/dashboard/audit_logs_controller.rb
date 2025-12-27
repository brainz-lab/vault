module Dashboard
  class AuditLogsController < BaseController
    before_action :require_project!

    def index
      @logs = current_project.audit_logs.order(created_at: :desc)

      if params[:action_filter].present?
        @logs = @logs.where(action: params[:action_filter])
      end

      if params[:secret_id].present?
        @logs = @logs.where(secret_id: params[:secret_id])
      end

      if params[:from].present?
        @logs = @logs.where("created_at >= ?", Date.parse(params[:from]).beginning_of_day)
      end

      if params[:to].present?
        @logs = @logs.where("created_at <= ?", Date.parse(params[:to]).end_of_day)
      end

      @page = (params[:page] || 1).to_i
      @per_page = 50
      @total_count = @logs.count
      @logs = @logs.limit(@per_page).offset((@page - 1) * @per_page)

      respond_to do |format|
        format.html
        format.turbo_stream
        format.csv { send_data export_csv(@logs), filename: "audit_logs_#{Date.current}.csv" }
      end
    end

    def show
      @log = current_project.audit_logs.find(params[:id])
    end

    private

    def export_csv(logs)
      require "csv"

      CSV.generate(headers: true) do |csv|
        csv << ["Timestamp", "Action", "Secret", "Actor", "IP Address", "Details"]
        logs.each do |log|
          csv << [
            log.created_at.iso8601,
            log.action,
            log.secret&.key,
            log.actor_name,
            log.ip_address,
            log.details.to_json
          ]
        end
      end
    end
  end
end
