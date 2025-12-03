require 'rspec'
require 'active_record'
require 'delayed_job'
require 'delayed_job_active_record'

require_relative '../lib/pipeline'
require_relative 'database_integration_helper'
require_relative 'models'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.syntax = [:should, :expect]
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax = [:should, :expect]
  end
end

ActiveRecord::Base.logger = Logger.new('pipeline.log')

at_exit do
  File.delete('pipeline.log') if File.exist?('pipeline.log')
end
