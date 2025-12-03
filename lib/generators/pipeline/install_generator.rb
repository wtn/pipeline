require 'rails/generators'
require 'rails/generators/active_record'

module Pipeline
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      desc 'Creates migration files for Pipeline tables'

      def create_migration_file
        migration_template 'migration.rb', 'db/migrate/create_pipeline_tables.rb'
      end
    end
  end
end
