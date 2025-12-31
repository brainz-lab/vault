module Api
  module V1
    class FoldersController < BaseController
      before_action :set_folder, only: [ :show, :update, :destroy ]

      # GET /api/v1/folders
      def index
        folders = current_project.secret_folders.order(:path)

        render json: {
          folders: folders.map { |f| folder_json(f) }
        }
      end

      # GET /api/v1/folders/*path
      def show
        render json: folder_json(@folder, include_secrets: true)
      end

      # POST /api/v1/folders
      def create
        require_permission!("write")

        @folder = current_project.secret_folders.build(folder_params)
        @folder.save!

        log_access(action: "create_folder", details: { path: @folder.path })

        render json: folder_json(@folder), status: :created
      end

      # PUT/PATCH /api/v1/folders/*path
      def update
        require_permission!("write")

        @folder.update!(folder_params)

        log_access(action: "update_folder", details: { path: @folder.path })

        render json: folder_json(@folder)
      end

      # DELETE /api/v1/folders/*path
      def destroy
        require_permission!("admin")

        if @folder.secrets.exists?
          render json: { error: "Cannot delete folder with secrets" }, status: :unprocessable_entity
          return
        end

        @folder.destroy!

        log_access(action: "delete_folder", details: { path: @folder.path })

        head :no_content
      end

      private

      def set_folder
        @folder = current_project.secret_folders.find_by!(path: params[:path])
      end

      def folder_params
        params.permit(:name, :path, :description, :parent_id)
      end

      def folder_json(folder, include_secrets: false)
        json = {
          id: folder.id,
          name: folder.name,
          path: folder.path,
          description: folder.description,
          secrets_count: folder.secrets.count,
          created_at: folder.created_at
        }

        if include_secrets
          json[:secrets] = folder.secrets.active.map do |s|
            {
              key: s.key,
              path: s.path,
              updated_at: s.updated_at
            }
          end
        end

        json
      end
    end
  end
end
