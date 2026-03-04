# frozen_string_literal: true

module NaviRuby
  module Collectors
    class SidekiqCollector
      def call(worker, job, queue)
        return yield unless NaviRuby.config.enabled

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        job_class = job['class'] || worker.class.name
        jid = job['jid']
        arguments = job['args']

        # Link SQL queries within this job to the jid
        Thread.current[:navi_ruby_request_id] = jid

        begin
          yield

          record_job(
            job_class: job_class,
            queue: queue,
            jid: jid,
            status: 'completed',
            duration_ms: calculate_duration(start_time),
            error_class: nil,
            arguments: arguments
          )
        rescue StandardError => e
          record_job(
            job_class: job_class,
            queue: queue,
            jid: jid,
            status: 'failed',
            duration_ms: calculate_duration(start_time),
            error_class: e.class.name,
            arguments: arguments
          )
          raise
        ensure
          Thread.current[:navi_ruby_request_id] = nil
        end
      end

      private

      def calculate_duration(start_time)
        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ((end_time - start_time) * 1000.0)
      end

      def record_job(job_class:, queue:, jid:, status:, duration_ms:, error_class:, arguments: nil)
        return unless NaviRuby.config.enabled

        NaviRuby.record_event(
          type: 'background_job',
          job_class: job_class,
          queue: queue,
          jid: jid,
          status: status,
          duration_ms: duration_ms,
          error_class: error_class,
          arguments: arguments,
          server_id: NaviRuby.server_id
        )
      rescue StandardError
        nil
      end
    end
  end
end
