module Api
  module V1
    class ConnectorsController < BaseController
      # GET /api/v1/connectors
      def index
        connectors = Connector.enabled

        connectors = connectors.by_type(params[:type]) if params[:type].present?
        connectors = connectors.by_category(params[:category]) if params[:category].present?
        connectors = connectors.search(params[:q]) if params[:q].present?
        connectors = connectors.installed if params[:installed] == "true"

        connectors = connectors.order(:display_name)

        render json: {
          connectors: connectors.map(&:to_catalog_entry),
          total: connectors.size
        }
      end

      # GET /api/v1/connectors/:id
      def show
        connector = Connector.enabled.find(params[:id])
        render json: { connector: connector.to_detail }
      end

      # GET /api/v1/connectors/:id/actions
      def actions
        connector = Connector.enabled.find(params[:id])
        render json: {
          connector: connector.piece_name,
          actions: connector.actions
        }
      end
    end
  end
end
