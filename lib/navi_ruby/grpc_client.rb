# frozen_string_literal: true

require_relative 'proto/ingest_pb'
require_relative 'proto/ingest_services_pb'

module NaviRuby
  # Sends batches of events to the Navi gRPC server.
  #
  # Auth is passed as gRPC call metadata — same credentials as the HTTP transport:
  #   authorization:   "Bearer <api_key>"
  #   x-project-name: "<app_name>"
  #
  # The stub is lazily created and cached. If the connection is lost,
  # a new stub is created on the next flush (gRPC stubs are cheap to construct).
  #
  # Usage (automatic via EventBuffer when transport: :grpc):
  #   NaviRuby::GrpcClient.post(events)
  class GrpcClient
    DEADLINE = 5 # seconds

    def self.post(events)
      new.post(events)
    end

    def post(events)
      request = build_request(events)
      metadata = build_metadata

      warn "[NaviRuby][gRPC] Sending #{events.size} events to #{grpc_address}"
      warn "[NaviRuby][gRPC] metadata=#{metadata.inspect}"

      stub.ingest(request, metadata: metadata, deadline: Time.now + DEADLINE)
      warn "[NaviRuby][gRPC] OK — #{events.size} events accepted"
      true
    rescue GRPC::ResourceExhausted => e
      warn "[NaviRuby][gRPC] RESOURCE_EXHAUSTED: #{e.message}"
      false
    rescue GRPC::Unauthenticated => e
      warn "[NaviRuby][gRPC] UNAUTHENTICATED: #{e.message}"
      false
    rescue StandardError => e
      warn "[NaviRuby][gRPC] ERROR #{e.class}: #{e.message}"
      warn e.backtrace.first(5).join("\n")
      false
    end

    private

    def stub
      @stub ||= Navi::IngestService::Stub.new(
        grpc_address,
        credentials,
        channel_args: { 'grpc.enable_retries' => 1 }
      )
    end

    def grpc_address
      url = NaviRuby.config.grpc_url.to_s
      # URI.parse only works correctly with a scheme; grpc_url may be "host:port"
      uri = URI.parse(url.include?('://') ? url : "grpc://#{url}")
      "#{uri.host}:#{uri.port}"
    rescue StandardError
      url
    end

    def credentials
      url = NaviRuby.config.grpc_url.to_s
      uri = URI.parse(url.include?('://') ? url : "grpc://#{url}")
      if uri.scheme == 'https' || uri.port == 443
        GRPC::Core::ChannelCredentials.new
      else
        :this_channel_is_insecure
      end
    rescue StandardError
      :this_channel_is_insecure
    end

    def build_metadata
      {
        'authorization' => "Bearer #{NaviRuby.config.api_key}",
        'x-project-name' => NaviRuby.config.app_name.to_s
      }
    end

    def build_request(events)
      proto_events = events.map { |e| build_event(e) }
      Navi::IngestRequest.new(events: proto_events)
    end

    def build_event(e)
      Navi::Event.new(
        type: e[:type].to_s,
        request_id: e[:request_id].to_s,
        server_id: e[:server_id].to_s,
        inserted_at: e[:created_at]&.iso8601.to_s,
        environment: e[:environment].to_s,
        # request / request_metadata
        endpoint: e[:endpoint].to_s,
        path: e[:path].to_s,
        http_method: (e[:http_method] || e[:method]).to_s,
        status: e[:status].to_i,
        duration_ms: e[:duration_ms].to_f,
        db_runtime_ms: e[:db_runtime_ms].to_f,
        view_runtime_ms: e[:view_runtime_ms].to_f,
        ip: e[:ip].to_s,
        user_ref: e[:user_ref].to_s,
        meta: stringify_map(e[:meta]),
        # query
        sql: e[:sql].to_s,
        sql_fingerprint: e[:sql_fingerprint].to_s,
        cached: e[:cached] == true,
        source_location: e[:source_location].to_s,
        # background_job
        job_class: e[:job_class].to_s,
        queue: e[:queue].to_s,
        jid: e[:jid].to_s,
        job_status: e[:status].to_s,
        error_class: e[:error_class].to_s,
        arguments: serialize_arguments(e[:arguments]),
        # system_metric
        role: e[:role].to_s,
        cpu_pct: e[:cpu_pct].to_f,
        mem_mb: e[:mem_mb].to_f,
        mem_pct: e[:mem_pct].to_f,
        disk_pct: e[:disk_pct].to_f,
        # custom event
        name: e[:name].to_s,
        event_type: e[:event_type].to_s,
        metadata: stringify_map(e[:metadata])
      )
    end

    def stringify_map(hash)
      return {} unless hash.is_a?(Hash)

      hash.transform_keys(&:to_s).transform_values do |v|
        if v.is_a?(String)
          v
        elsif v.is_a?(Numeric) || v.is_a?(TrueClass) || v.is_a?(FalseClass)
          v.to_s
        else
          begin
            require 'json' unless defined?(JSON)
            v.to_json
          rescue StandardError
            v.to_s
          end
        end
      end
    end

    def serialize_arguments(arguments)
      return '' unless arguments.is_a?(Array) && !arguments.empty?

      begin
        JSON.generate(arguments)
      rescue StandardError
        ''
      end
    end
  end
end
