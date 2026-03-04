# NANOCO APM

Self-hosted Application Performance Monitoring for Rails applications.

## Features

- **Zero-latency collection**: All writes are async via Sidekiq
- **PostgreSQL storage**: No Redis dependency, uses existing RDS
- **N+1 detection**: Automatic detection of query patterns
- **Percentile metrics**: P50/P95/P99 response times
- **Sidekiq monitoring**: Job throughput, duration, and failure rates
- **System metrics**: CPU, memory, and disk utilization
- **Dashboard**: Built-in Rails Engine with charts

## Installation

Add to your Gemfile:

```ruby
gem 'navi_ruby', path: 'path/to/navi_ruby'
```

Run the installer:

```bash
bundle install
rails generate navi_ruby:install
rails db:migrate
```

## Configuration

Edit `config/initializers/navi_ruby.rb`:

```ruby
NaviRuby.setup do |config|
  config.enabled = true
  config.retention_days = 7
  
  # Reduce write volume in production
  config.min_query_duration_ms = 10
  config.query_sample_rate = 0.5
  
  # Authentication
  config.http_basic_authentication_enabled = true
  config.http_basic_authentication_user = 'admin'
  config.http_basic_authentication_pass = 'secure_password'
end
```

## Usage

Access the dashboard at `/navi/apm`.

### Recording Deploy Events

```ruby
NaviRuby::Event.record_deploy("Deploy v2.3.1", metadata: { commit: 'abc123' })
```

### Recording Custom Events

```ruby
NaviRuby::Event.record_custom("Feature flag enabled", metadata: { flag: 'new_checkout' })
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NANOCO_APM_SERVER_ROLE` | Server role: `web`, `sidekiq`, or `rake` | auto-detected |

> **Note:** `server_id` is auto-detected per instance via hostname. No configuration needed for multi-instance deployments.

## Optional Gems

For system metrics collection:

```ruby
gem 'sys-cpu'
gem 'get_process_mem'
gem 'sys-filesystem'
```

## License

MIT
