# frozen_string_literal: true

module NaviRuby
  class Engine < ::Rails::Engine
    initializer 'navi_ruby.middleware' do |app|
      app.middleware.use NaviRuby::Collectors::RackMiddleware
    end

    initializer 'navi_ruby.notifications' do
      ActiveSupport.on_load(:active_record) do
        NaviRuby::Collectors::QueryCollector.subscribe
      end

      ActiveSupport.on_load(:action_controller) do
        NaviRuby::Collectors::RequestCollector.subscribe
      end
    end

    initializer 'navi_ruby.sidekiq' do
      if defined?(Sidekiq)
        Sidekiq.configure_server do |config|
          config.server_middleware do |chain|
            chain.add NaviRuby::Collectors::SidekiqCollector
          end
        end
      end
    end

    config.after_initialize do
      if NaviRuby.config.enabled
        NaviRuby::EventBuffer.instance.start_flush_timer
        NaviRuby::Collectors::SystemCollector.start_sampling_timer
      end
    end
  end
end
