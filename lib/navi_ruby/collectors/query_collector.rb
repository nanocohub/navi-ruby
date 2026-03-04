# frozen_string_literal: true

require 'digest/sha1'

module NaviRuby
  module Collectors
    class QueryCollector
      IGNORED_COMMANDS = %w[SCHEMA CACHE].freeze

      def self.subscribe
        ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, start, finish, _id, payload|
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
        return unless NaviRuby.config.sample_query?

        event = build_event
        NaviRuby.record_event(event)
      end

      private

      def ignore?
        return true if IGNORED_COMMANDS.include?(@payload[:name])
        return true if sql.include?('navi_ruby_')
        return true if NaviRuby.config.ignore_sql?(sql)
        return true if duration_ms < NaviRuby.config.min_query_duration_ms

        false
      end

      def sql
        @sql ||= @payload[:sql].to_s
      end

      def duration_ms
        ((@finish - @start) * 1000.0)
      rescue StandardError
        0
      end

      def build_event
        {
          type: :query,
          request_id: Thread.current[:navi_ruby_request_id],
          sql: sql,
          sql_fingerprint: fingerprint,
          duration_ms: duration_ms,
          cached: @payload[:name] == 'CACHE',
          source_location: extract_source_location,
          created_at: Time.current
        }
      end

      def fingerprint
        normalized = normalize_sql(sql)
        Digest::SHA1.hexdigest(normalized)
      end

      def normalize_sql(sql_string)
        sql_string
          .gsub(/'[^']*'/, '?') # Replace single-quoted strings (values) with ?
          .gsub(/\b\d+\b/, '?') # Replace integers with ?
          .gsub(/\s+/, ' ')     # Collapse whitespace
          .strip
          .downcase
      end

      def extract_source_location
        # Start at frame 6 (skipping immediate AR/Notifications internals)
        # Look up to 100 frames deep to find where it originated in the user's app.
        locations = caller_locations(6, 100)
        return nil unless locations

        # 1. Try to find a frame in the user's /app/ directory
        app_location = locations.find do |loc|
          path = loc.absolute_path || loc.path
          path && path.include?('/app/') && !path.include?('/vendor/')
        end

        if app_location
          path = app_location.absolute_path || app_location.path
          line = app_location.lineno
          relative_path = path.split('/app/').last
          return "app/#{relative_path}:#{line}" if relative_path
        end

        # 2. Fallback: Find the first frame outside of NaviRuby and core Rails framework
        fallback_location = locations.find do |loc|
          path = loc.absolute_path || loc.path
          next false unless path

          !path.include?('/navi_ruby/') &&
            !path.match?(%r{/gems/(activerecord|activesupport|actionpack|railties|rack)-}) &&
            !path.include?('ruby/gems/') && # Catch other system gems if needed
            !path.include?('ruby/3.') # Skip standard library
        end

        # If we still can't find a non-framework frame, just take the first one outside NaviRuby
        fallback_location ||= locations.find do |loc|
          path = loc.absolute_path || loc.path
          path && !path.include?('/navi_ruby/')
        end

        if fallback_location
          path = fallback_location.absolute_path || fallback_location.path
          line = fallback_location.lineno

          if path.include?('/gems/')
            "#{path.split('/gems/').last}:#{line}"
          else
            "#{fallback_location.path}:#{line}"
          end
        end
      rescue StandardError
        nil
      end
    end
  end
end
