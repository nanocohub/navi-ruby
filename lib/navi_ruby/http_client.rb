# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module NaviRuby
  class HttpClient
    TIMEOUT = 5

    def self.post(events)
      new.post(events)
    end

    def post(events)
      uri = URI.parse("#{NaviRuby.config.server_url}/api/v1/ingest")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT

      request = Net::HTTP::Post.new(uri.path)
      request['Authorization'] = "Bearer #{NaviRuby.config.api_key}"
      request['X-Project-Name'] = NaviRuby.config.app_name.to_s
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate({ events: events })

      response = http.request(request)
      NaviRuby.log("Ingest response: #{response.code}") unless response.code == '202'
      response
    rescue StandardError => e
      NaviRuby.log("HTTP flush failed: #{e.message}")
      nil
    end
  end
end
