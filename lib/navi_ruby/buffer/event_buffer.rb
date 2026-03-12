# frozen_string_literal: true

require 'singleton'
require 'concurrent/array'
require 'concurrent/scheduled_task'

module NaviRuby
  class EventBuffer
    include Singleton

    attr_reader :buffer

    def initialize
      @buffer = Concurrent::Array.new
      @mutex = Mutex.new
      @scheduled_task = nil
      @shutdown = false
    end

    def push(event)
      return unless NaviRuby.config.enabled
      return if @shutdown

      @buffer << event
      flush_if_needed
    end

    def push_many(events)
      return unless NaviRuby.config.enabled
      return if @shutdown

      @buffer.concat(events)
      flush_if_needed
    end

    def flush_if_needed
      return unless @buffer.size >= NaviRuby.config.buffer_size

      flush
    end

    def flush
      return if @buffer.empty?

      events = drain
      return if events.empty?

      unless NaviRuby.config.server_mode?
        log_error('server_url/grpc_url and api_key are not configured — events dropped.')
        return
      end

      if NaviRuby.config.grpc?
        NaviRuby::GrpcClient.post(events)
      else
        NaviRuby::HttpClient.post(events)
      end
    rescue StandardError => e
      log_error("Flush failed: #{e.message}")
    end

    def drain
      @mutex.synchronize do
        events = @buffer.to_a
        @buffer.clear
        events
      end
    end

    def size
      @buffer.size
    end

    def start_flush_timer
      return if @scheduled_task&.pending?

      @scheduled_task = Concurrent::ScheduledTask.execute(NaviRuby.config.flush_interval) do
        flush
        start_flush_timer unless @shutdown
      end
    end

    def stop_flush_timer
      @shutdown = true
      @scheduled_task&.cancel
    end

    def shutdown
      stop_flush_timer
      flush
    end

    private

    def log_error(message)
      return unless config.respond_to?(:debug) && config.debug

      if defined?(Rails) && Rails.logger
        Rails.logger.error("[NaviRuby] #{message}")
      else
        warn("[NaviRuby] #{message}")
      end
    end
  end
end
