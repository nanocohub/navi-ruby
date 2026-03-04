# frozen_string_literal: true

require_relative 'test_helper'

class UtilsTest < Minitest::Test
  def test_fingerprint_sql_normalizes_strings
    sql = "SELECT * FROM users WHERE email = 'test@example.com'"
    result = NaviRuby::Utils.fingerprint_sql(sql)
    assert_includes result, '?'
    refute_includes result, 'test@example.com'
  end

  def test_fingerprint_sql_normalizes_integers
    sql = 'SELECT * FROM users WHERE id = 42'
    result = NaviRuby::Utils.fingerprint_sql(sql)
    assert_includes result, '?'
    refute_includes result, '42'
  end

  def test_fingerprint_sql_downcases
    sql = 'SELECT * FROM Users'
    result = NaviRuby::Utils.fingerprint_sql(sql)
    assert_equal result, result.downcase
  end

  def test_fingerprint_sql_nil
    assert_nil NaviRuby::Utils.fingerprint_sql(nil)
  end

  def test_truncate_short_string
    assert_equal 'hello', NaviRuby::Utils.truncate('hello', 200)
  end

  def test_truncate_long_string
    long = 'a' * 300
    result = NaviRuby::Utils.truncate(long, 200)
    assert result.end_with?('...')
    assert result.length <= 203
  end

  def test_truncate_nil
    assert_nil NaviRuby::Utils.truncate(nil)
  end

  def test_source_location_from_caller
    fake_caller = [
      "/Users/dev/.rbenv/versions/3.3.0/lib/ruby/gems/activerecord.rb:123:in `exec'",
      "/Users/dev/myapp/app/models/user.rb:45:in `find'"
    ]
    result = NaviRuby::Utils.source_location_from_caller(fake_caller)
    assert_equal 'app/models/user.rb', result
  end

  def test_source_location_from_caller_no_app_frame
    fake_caller = ["/usr/local/lib/ruby/activerecord.rb:123:in `exec'"]
    assert_nil NaviRuby::Utils.source_location_from_caller(fake_caller)
  end
end
