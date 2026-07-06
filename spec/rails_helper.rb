# frozen_string_literal: true

require "spec_helper"
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "inertia_rails/rspec"
require "capybara/rspec"
require "selenium-webdriver"
require "active_job/test_helper"

# Precompile Vite assets once before running the test suite
ViteRuby.commands.build

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before(type: :system) do
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
  end

  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers
  config.include ActiveJob::TestHelper
  config.include AuthenticationHelpers, type: ->(type, _metadata) { [:system, :request, :controller].include?(type) }

  config.before do
    ActiveJob::Base.queue_adapter = :test
  end

  config.after do
    clear_enqueued_jobs
    clear_performed_jobs
  end
end
