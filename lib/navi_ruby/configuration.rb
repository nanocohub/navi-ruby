# frozen_string_literal: true

module NaviRuby
  class Configuration
    attr_accessor :app_name,
                  :enabled,
                  :debug,
                  :server_url,
                  :grpc_url,
                  :transport,
                  :api_key,
                  :ignored_endpoints,
                  :ignored_paths,
                  :ignored_sql_patterns,
                  :min_query_duration_ms,
                  :query_sample_rate,
                  :buffer_size,
                  :flush_interval,
                  :system_sample_interval,
                  :custom_data_proc

    def initialize
      @app_name = (defined?(Rails) ? Rails.application.class.module_parent_name : 'Nanoco')
      @enabled = true
      @debug = false
      @server_url = nil
      @grpc_url = nil
      @transport = :http # :http or :grpc
      @api_key = nil
      @ignored_endpoints = []
      @ignored_paths = ['/health', '/assets']
      @ignored_sql_patterns = []
      @min_query_duration_ms = 0
      @query_sample_rate = 1.0
      @buffer_size = 500
      @flush_interval = 10
      @system_sample_interval = 60
      @custom_data_proc = proc { |_env| {} }
    end

    def server_mode?
      case transport
      when :grpc then !grpc_url.nil? && !api_key.nil?
      else !server_url.nil? && !api_key.nil?
      end
    end

    def grpc?
      transport.to_sym == :grpc
    end

    def ignore_endpoint?(endpoint)
      return false unless endpoint

      ignored_endpoints.any? { |pattern| pattern.is_a?(Regexp) ? endpoint =~ pattern : endpoint == pattern }
    end

    def ignore_path?(path)
      return false unless path

      ignored_paths.any? { |pattern| pattern.is_a?(Regexp) ? path =~ pattern : path.start_with?(pattern) }
    end

    def ignore_sql?(sql)
      return false unless sql

      ignored_sql_patterns.any? { |pattern| sql =~ pattern }
    end

    def sample_query?
      rand < query_sample_rate
    end

    def app_name
      @app_name ||= (defined?(Rails) ? Rails.application.class.module_parent_name : 'Nanoco')
    end
  end
end
