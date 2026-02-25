# frozen_string_literal: true

module NanocoApm
  class DashboardController < ApplicationController
    def index
      @period = (params[:period] || '24h').to_s
      @tab = (params[:tab] || 'overview').to_s

      return unless @tab == 'overview'

      @period_stats = (params[:stats_period] || '24h').to_s
      @period_requests = (params[:requests_period] || '24h').to_s
      @period_latency = (params[:latency_period] || '24h').to_s
      @period_issues = (params[:issues_period] || '24h').to_s
      @period_queries = (params[:queries_period] || '24h').to_s

      report_stats = Reports::OverviewReport.new(
        start_time: parse_period(@period_stats)[0],
        end_time: parse_period(@period_stats)[1]
      )
      @percentiles = report_stats.percentiles
      @error_rate = report_stats.error_rate
      @throughput = report_stats.throughput

      report_requests = Reports::OverviewReport.new(
        start_time: parse_period(@period_requests)[0],
        end_time: parse_period(@period_requests)[1]
      )
      @time_series_requests = report_requests.time_series(interval: get_interval(@period_requests))

      report_latency = Reports::OverviewReport.new(
        start_time: parse_period(@period_latency)[0],
        end_time: parse_period(@period_latency)[1]
      )
      @time_series_latency = report_latency.time_series(interval: get_interval(@period_latency))

      report_issues = Reports::OverviewReport.new(
        start_time: parse_period(@period_issues)[0],
        end_time: parse_period(@period_issues)[1]
      )
      @issues = report_issues.issues

      report_queries = Reports::OverviewReport.new(
        start_time: parse_period(@period_queries)[0],
        end_time: parse_period(@period_queries)[1]
      )
      @top_slow_queries = report_queries.top_slow_queries(limit: 10)
    end

    private

    def parse_period(period)
      end_time = Time.current
      start_time = case period
                   when '15m' then 15.minutes.ago
                   when '1h' then 1.hour.ago
                   when '6h' then 6.hours.ago
                   when '24h' then 24.hours.ago
                   when '7d' then 7.days.ago
                   else 24.hours.ago
                   end
      [start_time, end_time]
    end

    def get_interval(period)
      case period
      when '15m', '1h' then 'minute'
      when '6h', '24h' then 'hour'
      else 'day'
      end
    end
  end
end
