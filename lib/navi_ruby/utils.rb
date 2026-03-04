# frozen_string_literal: true

module NaviRuby
  module Utils
    class << self
      def fingerprint_sql(sql)
        return nil unless sql

        sql
          .gsub(/'\S+'/, '?')
          .gsub(/"\S+"/, '?')
          .gsub(/\b\d+\b/, '?')
          .gsub(/\s+/, ' ')
          .strip
          .downcase
      end

      def truncate(str, length = 200)
        return nil unless str

        str.length > length ? "#{str[0...length]}..." : str
      end

      def source_location_from_caller(caller_array)
        return nil unless caller_array

        app_frame = caller_array.find { |loc| loc.include?('/app/') }
        return nil unless app_frame

        match = app_frame.match(%r{/(app/.*\.rb):\d+})
        match ? match[1] : nil
      end
    end
  end
end
