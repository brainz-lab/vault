module Connectors
  module Native
    class Base
      def initialize(credentials)
        @credentials = credentials || {}
      end

      def execute(action, **params)
        raise NotImplementedError, "#{self.class} must implement #execute"
      end

      def self.actions
        []
      end

      def self.piece_name
        raise NotImplementedError
      end

      def self.display_name
        piece_name.titleize
      end

      def self.description
        ""
      end

      def self.category
        "other"
      end

      def self.auth_type
        "NONE"
      end

      def self.auth_schema
        {}
      end

      def self.logo_url
        nil
      end

      protected

      attr_reader :credentials
    end
  end
end
