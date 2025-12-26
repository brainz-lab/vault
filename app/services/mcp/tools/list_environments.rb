module Mcp
  module Tools
    class ListEnvironments < Base
      DESCRIPTION = "List all available environments in the vault."
      INPUT_SCHEMA = {
        type: "object",
        properties: {},
        required: []
      }.freeze

      def call(_params)
        environments = project.secret_environments.order(:position)

        success(
          environments: environments.map do |env|
            {
              slug: env.slug,
              name: env.name,
              locked: env.locked,
              inherits_from: env.inherits_from
            }
          end,
          current: environment.slug
        )
      end
    end
  end
end
