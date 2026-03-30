# frozen_string_literal: true

module Connectors
  module Manifest
    # Handles stream partitioning and incremental sync cursors.
    #
    # Maps to Airbyte's:
    # - DatetimeBasedCursor: slice by time windows
    # - ListPartitionRouter: iterate over a list of values
    #
    class StreamSlicer
      def initialize(config, interpolator:)
        @config = config || {}
        @interpolator = interpolator
      end

      # Yields stream_slice hashes for each partition.
      def each_slice(&block)
        type = @config["type"] || @config[:type]

        case type
        when "DatetimeBasedCursor"
          datetime_slices(&block)
        when "ListPartitionRouter"
          list_slices(&block)
        else
          yield({})
        end
      end

      private

      def datetime_slices
        start_dt = parse_datetime(@config["start_datetime"] || @config[:start_datetime])
        end_dt = parse_datetime(@config["end_datetime"] || @config[:end_datetime] || Time.current.iso8601)
        step = parse_duration(@config["step"] || @config[:step] || "P1D")
        cursor_field = @config["cursor_field"] || @config[:cursor_field]

        current = start_dt
        while current < end_dt
          slice_end = [current + step, end_dt].min
          yield({
            "start_time" => format_datetime(current),
            "end_time" => format_datetime(slice_end),
            "cursor_field" => cursor_field
          })
          current = slice_end
        end
      end

      def list_slices
        values = @config["values"] || @config[:values] || []
        cursor_field = @config["cursor_field"] || @config[:cursor_field]

        # Resolve interpolated values
        resolved = @interpolator.interpolate(values)
        resolved = resolved.is_a?(Array) ? resolved : [resolved]

        resolved.each do |value|
          yield({ "partition" => value, cursor_field => value })
        end
      end

      def parse_datetime(value)
        resolved = @interpolator.interpolate(value.to_s)
        Time.parse(resolved)
      rescue ArgumentError, TypeError
        Time.current - 30.days
      end

      def format_datetime(time)
        fmt = @config["datetime_format"] || @config[:datetime_format] || "%Y-%m-%dT%H:%M:%SZ"
        time.strftime(fmt)
      end

      def parse_duration(duration_str)
        # ISO 8601 duration: P1D, P7D, P1M, PT1H, etc.
        case duration_str.to_s
        when /P(\d+)D/ then Regexp.last_match(1).to_i.days
        when /P(\d+)W/ then Regexp.last_match(1).to_i.weeks
        when /P(\d+)M/ then Regexp.last_match(1).to_i.months
        when /PT(\d+)H/ then Regexp.last_match(1).to_i.hours
        else 1.day
        end
      end
    end
  end
end
