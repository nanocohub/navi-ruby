# frozen_string_literal: true

require_relative 'test_helper'

class ConfigurationTest < Minitest::Test
  def setup
    @config = NaviRuby::Configuration.new
  end

  def test_default_enabled
    assert @config.enabled
  end

  def test_default_retention_days
    assert_equal 7, @config.retention_days
  end

  def test_default_buffer_size
    assert_equal 500, @config.buffer_size
  end

  def test_default_query_sample_rate
    assert_equal 1.0, @config.query_sample_rate
  end

  def test_ignore_endpoint_string_match
    @config.ignored_endpoints = ['HealthController#check']
    assert @config.ignore_endpoint?('HealthController#check')
    refute @config.ignore_endpoint?('UsersController#index')
  end

  def test_ignore_endpoint_regex_match
    @config.ignored_endpoints = [/Health/]
    assert @config.ignore_endpoint?('HealthController#check')
    refute @config.ignore_endpoint?('UsersController#index')
  end

  def test_ignore_path_prefix_match
    @config.ignored_paths = ['/health', '/assets']
    assert @config.ignore_path?('/health')
    assert @config.ignore_path?('/health/check')
    refute @config.ignore_path?('/users')
  end

  def test_ignore_path_regex_match
    @config.ignored_paths = [%r{\A/assets}]
    assert @config.ignore_path?('/assets/application.js')
    refute @config.ignore_path?('/users')
  end

  def test_ignore_sql
    @config.ignored_sql_patterns = [/pg_catalog/]
    assert @config.ignore_sql?('SELECT * FROM pg_catalog.pg_tables')
    refute @config.ignore_sql?('SELECT * FROM users')
  end

  def test_sample_query_full_rate
    @config.query_sample_rate = 1.0
    assert @config.sample_query?
  end

  def test_sample_query_zero_rate
    @config.query_sample_rate = 0.0
    refute @config.sample_query?
  end

  def test_custom_setter
    @config.retention_days = 30
    assert_equal 30, @config.retention_days
  end
end
