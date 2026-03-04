# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'navi-ruby'
  spec.version = '1.0.0'
  spec.authors = ['NANOCO Engineering']
  spec.email = ['engineering@nanoco.vn']
  spec.homepage = 'https://github.com/nanoco/navi_ruby'
  spec.summary = 'Self-hosted APM for Rails applications'
  spec.description = 'Lightweight, self-hosted application performance monitoring for Rails. ' \
                     'Tracks requests, SQL queries, Sidekiq jobs and system metrics with zero SaaS dependency.'
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 3.1'

  spec.files = Dir['lib/**/*', 'MIT-LICENSE', 'README.md']
  spec.require_path = 'lib'

  spec.add_dependency 'concurrent-ruby', '>= 1.0'
  spec.add_dependency 'railties', '>= 6.1'
  # sidekiq is optional — SidekiqCollector loads only when Sidekiq is defined
  # grpc is optional — GrpcClient loads only when transport: :grpc is configured
  spec.add_dependency 'get_process_mem'
  spec.add_dependency 'google-protobuf', '>= 3.21'
  spec.add_dependency 'grpc', '>= 1.50'
  spec.add_dependency 'sys-cpu'
  spec.add_dependency 'sys-filesystem'
end
