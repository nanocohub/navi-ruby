# frozen_string_literal: true

require 'securerandom'
require 'socket'

module NaviRuby
  module Collectors
    class RackMiddleware
      REQUEST_ID_KEY = :navi_ruby_request_id
      REQUEST_START_KEY = :navi_ruby_request_start
      USER_REF_KEY = :navi_ruby_user_ref
      REQUEST_META_KEY = :navi_ruby_request_meta

      def initialize(app)
        @app = app
      end

      def call(env)
        return @app.call(env) unless NaviRuby.config.enabled

        path = extract_path(env)
        return @app.call(env) if NaviRuby.config.ignore_path?(path)

        request_id = SecureRandom.uuid
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        Thread.current[REQUEST_ID_KEY] = request_id
        Thread.current[REQUEST_START_KEY] = start_time
        Thread.current[REQUEST_META_KEY] = nil

        begin
          request = ActionDispatch::Request.new(env)
          Thread.current[USER_REF_KEY] = extract_user(request, env)
        rescue StandardError
          Thread.current[USER_REF_KEY] = nil
        end

        custom_data = extract_custom_data(env)

        status, headers, response = @app.call(env)

        [status, headers, response]
      ensure
        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        duration_ms = begin
          ((end_time - Thread.current[REQUEST_START_KEY]) * 1000.0)
        rescue StandardError
          0
        end

        record_request(env, request_id, duration_ms, custom_data) if request_id

        Thread.current[REQUEST_ID_KEY] = nil
        Thread.current[REQUEST_START_KEY] = nil
        Thread.current[USER_REF_KEY] = nil
        Thread.current[REQUEST_META_KEY] = nil
      end

      def self.request_id
        Thread.current[REQUEST_ID_KEY]
      end

      private

      def extract_user(request, env)
        # 1. Safely check Warden without triggering lazy-load DB queries
        if (warden = request.env['warden'])
          # Warden stores the raw user ID in the session hash under keys like 'warden.user.user.key'
          user_key = begin
            warden.session(warden.config.default_scope)
          rescue StandardError
            nil
          end
          return user_key.first.first.to_s if user_key.is_a?(Array) && user_key.first.is_a?(Array)
        end

        # 2. Try JWT Auth Header
        auth_header = env['HTTP_AUTHORIZATION'] || request.headers['Authorization']
        if auth_header.is_a?(String) && auth_header.match?(/^Bearer /i)
          token = auth_header.split(' ').last
          if token
            if token.count('.') == 2
              begin
                require 'base64'
                require 'json'
                payload_str = token.split('.')[1]
                # Pad string to make it valid base64 before decoding
                payload_str = payload_str.ljust((payload_str.length + 3) & ~3, '=')
                payload = Base64.urlsafe_decode64(payload_str)
                parsed = JSON.parse(payload)

                user_id = parsed['user_id'] || parsed['sub'] || parsed['id']
                return user_id.to_s if user_id
              rescue StandardError
                # Fall back if JSON parsing or Base64 decoding fails
              end
            end
            return token.slice(0, 15)
          end
        end

        # 3. Standard Session
        if request.respond_to?(:session) && request.session.loaded? && request.session[:user_id]
          return request.session[:user_id].to_s
        end

        nil
      end

      def extract_custom_data(env)
        NaviRuby.config.custom_data_proc.call(env)
      rescue StandardError
        {}
      end

      def record_request(env, request_id, duration_ms, custom_data)
        path = extract_path(env)
        return if NaviRuby.config.ignore_path?(path)

        meta_event = Thread.current[REQUEST_META_KEY] || {}
        NaviRuby.log("DEBUG: RackMiddleware read meta from Thread: #{meta_event[:meta]&.keys.inspect}")

        # Merge controller data and custom metadata
        meta = (meta_event[:meta] || {}).merge(custom_data || {})

        if meta.empty?
          NaviRuby.log("WARN: No meta collected for request #{request_id}")
        else
          NaviRuby.log("INFO: Meta found for request #{request_id}: #{meta.keys}")
        end

        event = {
          type: :request,
          request_id: request_id,
          endpoint: meta_event[:endpoint],
          path: path,
          http_method: env['REQUEST_METHOD'] || 'GET',
          status: meta_event[:status] || env['action_dispatch.request.path_parameters']&.dig(:status) || 200,
          db_runtime_ms: meta_event[:db_runtime_ms],
          view_runtime_ms: meta_event[:view_runtime_ms],
          ip: extract_ip(env),
          user_ref: Thread.current[USER_REF_KEY],
          server_id: NaviRuby.server_id,
          environment: NaviRuby.environment,
          duration_ms: duration_ms,
          meta: meta.empty? ? nil : meta,
          created_at: Time.current
        }.compact

        NaviRuby.record_event(event)
      end

      def extract_path(env)
        env['PATH_INFO'] || '/'
      end

      def extract_ip(env)
        env['HTTP_X_FORWARDED_FOR']&.split(',')&.first&.strip ||
          env['HTTP_X_REAL_IP'] ||
          env['REMOTE_ADDR'] ||
          'unknown'
      end
    end
  end
end
