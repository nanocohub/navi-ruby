# frozen_string_literal: true

module NaviRuby
  module Collectors
    class RequestCollector
      def self.subscribe
        ActiveSupport::Notifications.subscribe('process_action.action_controller') do |_name, start, finish, _id, payload|
          new(start, finish, payload).record
        end
      end

      def initialize(start, finish, payload)
        @start = start
        @finish = finish
        @payload = payload
      end

      def record
        return unless NaviRuby.config.enabled
        return if ignore?

        event = build_event
        Thread.current[:navi_ruby_request_meta] = event
        NaviRuby.log("DEBUG: RequestCollector stored meta in Thread: #{event[:meta]&.keys.inspect}")
      end

      private

      def ignore?
        endpoint = "#{@payload[:controller]}##{@payload[:action]}"
        NaviRuby.config.ignore_endpoint?(endpoint)
      end

      def build_event
        event = {
          type: :request_metadata,
          request_id: Thread.current[:navi_ruby_request_id],
          endpoint: endpoint,
          controller: @payload[:controller],
          action: @payload[:action],
          status: @payload[:status],
          db_runtime_ms: @payload[:db_runtime],
          view_runtime_ms: @payload[:view_runtime],
          format: @payload[:format],
          method: @payload[:method],
          created_at: Time.current
        }

        if @payload[:params]
          safe_params = @payload[:params].except(:controller, :action, :format, 'controller', 'action', 'format')

          meta = {
            params: safe_params.empty? ? nil : safe_params,
            query: @payload[:params][:query]&.slice(0, 10_000),
            operationName: @payload[:params][:operationName]&.slice(0, 500),
            variables: sanitize_variables(@payload[:params][:variables]),
            stats: extract_graphql_stats
          }.compact

          # Only set meta if we actually collected something
          event[:meta] = meta unless meta.empty?
        end

        event
      end

      def extract_graphql_stats
        stats = {}

        # 1. Try to read from response headers (e.g., host app added them via response.set_header)
        if @payload[:response] && @payload[:response].respond_to?(:headers)
          %w[graphql_query_complexity graphql_query_depth].each do |key|
            if (value = @payload[:response].headers[key])
              stats[key.gsub('graphql_', '').to_sym] = value.is_a?(String) ? value.to_i : value
            end
          end
        end

        # 2. Try to read from request.env (if host app passed a hash there)
        if @payload[:request] && @payload[:request].respond_to?(:env) && @payload[:request].env['graphql_stats'].is_a?(Hash)
          stats.merge!(@payload[:request].env['graphql_stats'])
        end

        stats.empty? ? nil : stats
      end

      def sanitize_variables(vars)
        return nil unless vars

        # If it's a string (e.g., from some clients), try to parse it or just keep a safe slice
        return vars.slice(0, 5000) if vars.is_a?(String)

        begin
          json_vars = vars.to_json
          json_vars.bytesize < 10_000 ? vars : { error: 'variables_too_large' }
        rescue StandardError
          nil
        end
      end

      def endpoint
        controller = @payload[:controller]
        action = @payload[:action]
        return nil unless controller && action

        "#{controller.gsub(/Controller$/, '')}##{action}"
      end
    end
  end
end
