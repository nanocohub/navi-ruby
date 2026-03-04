# frozen_string_literal: true

require 'socket'

begin
  require 'sys/cpu'
rescue LoadError
  Sys::CPU = nil
end

begin
  require 'sys/filesystem'
rescue LoadError
  Sys::Filesystem = nil
end

begin
  require 'get_process_mem'
rescue LoadError
  GetProcessMem = nil
end

module NaviRuby
  module Collectors
    class SystemCollector
      def self.start_sampling_timer
        return if @shutdown

        @task = Concurrent::ScheduledTask.execute(NaviRuby.config.system_sample_interval) do
          capture
          start_sampling_timer unless @shutdown
        end
      end

      def self.stop_sampling_timer
        @shutdown = true
        @task&.cancel
      end

      def self.capture
        return unless NaviRuby.config.enabled

        metrics = new.capture
        return unless metrics

        NaviRuby.record_event(metrics.merge(type: 'system_metric'))
      rescue StandardError
        nil
      end

      def capture
        {
          server_id: NaviRuby.server_id,
          role: NaviRuby.server_role,
          cpu_pct: capture_cpu,
          mem_mb: capture_memory_mb,
          mem_pct: capture_memory_pct,
          disk_pct: capture_disk
        }
      end

      private

      def capture_cpu
        return nil unless defined?(Sys::CPU) && Sys::CPU

        load_avg = Sys::CPU.load_avg
        return nil unless load_avg

        cpu_count = Sys::CPU.processors&.size || 1
        (load_avg.first.to_f / cpu_count.to_f) * 100.0
      rescue StandardError
        capture_cpu_fallback
      end

      def capture_cpu_fallback
        if File.exist?('/proc/loadavg')
          load_avg = File.read('/proc/loadavg').split.first.to_f
          cpu_count = Etc.nprocessors || 1
          (load_avg / cpu_count) * 100.0
        elsif system('which top > /dev/null 2>&1')
          result = `top -l 1 -n 0 2>/dev/null | grep "CPU usage" | awk '{print $3}' | tr -d '%'`
          result.strip.to_f
        end
      rescue StandardError
        nil
      end

      def capture_memory_mb
        return nil unless defined?(GetProcessMem) && GetProcessMem

        GetProcessMem.new.mb
      rescue StandardError
        nil
      end

      def capture_memory_pct
        return nil unless defined?(GetProcessMem) && GetProcessMem

        mem = GetProcessMem.new
        total = total_system_memory
        return nil unless total && total > 0

        (mem.mb.to_f / total.to_f) * 100.0
      rescue StandardError
        nil
      end

      def capture_disk
        return nil unless defined?(Sys::Filesystem) && Sys::Filesystem

        stat = Sys::Filesystem.stat('/')
        stat.percent_used
      rescue StandardError
        capture_disk_fallback
      end

      def capture_disk_fallback
        if File.exist?('/proc/mounts')
          result = `df -BG / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%'`
          result.strip.to_i
        elsif system('which df > /dev/null 2>&1')
          result = `df -kg / 2>/dev/null | tail -1 | awk '{print $5}'`
          result.strip.to_i
        end
      rescue StandardError
        nil
      end

      def total_system_memory
        if File.exist?('/proc/meminfo')
          File.read('/proc/meminfo')[/MemTotal:\s+(\d+)/, 1].to_i / 1024
        elsif File.exist?('/usr/sbin/system_profiler')
          result = `/usr/sbin/system_profiler SPHardwareDataType 2>/dev/null`
          memory = result[/Memory:\s+(\d+)\s*GB/, 1]
          memory ? memory.to_i * 1024 : nil
        end
      rescue StandardError
        nil
      end
    end
  end
end
