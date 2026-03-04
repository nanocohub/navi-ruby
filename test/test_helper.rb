# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/pride'

# Load only the pure-Ruby parts (no Rails) for unit tests
require_relative '../lib/navi_ruby/version'
require_relative '../lib/navi_ruby/configuration'
require_relative '../lib/navi_ruby/utils'
