# frozen_string_literal: true

require 'socket'
require 'singleton'
require 'concurrent/array'
require 'concurrent/scheduled_task'

require_relative 'navi_ruby/version'
require_relative 'navi_ruby/configuration'

# Define core module API immediately after configuration is loaded.
# This must come before the remaining require_relative calls so that
# NaviRuby.configure / NaviRuby.config are always defined, even if a
# later require fails.
module NaviRuby
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield(config)
    end

    alias setup configure

    def record_event(event)
      return unless config.enabled

      EventBuffer.instance.push(event)
    end

    def server_id
      @server_id ||= Socket.gethostname
    end

    def server_role
      @server_role ||= detect_server_role
    end

    def environment
      @environment ||= detect_environment
    end

    def skip
      Thread.current[:navi_ruby_skip]
    end

    def skip=(value)
      Thread.current[:navi_ruby_skip] = value
    end

    def log(message)
      return unless config.respond_to?(:debug) && config.debug

      if defined?(Rails) && Rails.logger
        Rails.logger.debug("[NaviRuby] #{message}")
      else
        warn("[NaviRuby] #{message}")
      end
    end

    private

    def detect_server_role
      if defined?(Sidekiq) && Sidekiq.server?
        'worker'
      else
        'web'
      end
    end

    def detect_environment
      if defined?(Rails)
        Rails.env.to_s
      else
        ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
      end
    end
  end
end

require_relative 'navi_ruby/http_client'
require_relative 'navi_ruby/grpc_client'
require_relative 'navi_ruby/utils'
require_relative 'navi_ruby/buffer/event_buffer'
require_relative 'navi_ruby/collectors/rack_middleware'
require_relative 'navi_ruby/collectors/request_collector'
require_relative 'navi_ruby/collectors/query_collector'
require_relative 'navi_ruby/collectors/system_collector'

require_relative 'navi_ruby/collectors/sidekiq_collector' if defined?(Sidekiq)

require_relative 'navi_ruby/engine'
