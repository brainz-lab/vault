module Dashboard
  class ConnectorsController < BaseController
    before_action :require_project!

    PER_PAGE = 36

    def index
      scope = Connector.enabled

      if params[:search].present?
        scope = scope.search(params[:search])
      end

      if params[:category].present?
        scope = scope.by_category(params[:category])
      end

      if params[:connector_type].present?
        scope = scope.by_type(params[:connector_type])
      end

      @total_count = scope.count
      @page = [params[:page].to_i, 1].max
      @total_pages = (@total_count.to_f / PER_PAGE).ceil
      @page = @total_pages if @page > @total_pages && @total_pages > 0

      @connectors = scope.order(:display_name).offset((@page - 1) * PER_PAGE).limit(PER_PAGE)

      # Preload connection status for current project
      @connected_connector_ids = current_project.connector_connections
                                                 .connected
                                                 .pluck(:connector_id)
                                                 .to_set
    end

    def show
      @connector = Connector.find(params[:id])
      @connections = current_project.connector_connections
                                    .where(connector: @connector)
                                    .includes(:connector_credential)
      @credentials = current_project.connector_credentials
                                    .where(connector: @connector)
    end

    def actions
      @connector = Connector.find(params[:id])
      render json: { actions: @connector.actions || [] }
    end
  end
end
