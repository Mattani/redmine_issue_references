# frozen_string_literal: true

# advanced_plugin_helper defines redmine:plugins:test:helpers using
# Rails::TestUnit::Runner.rake_run, which was removed in Rails 7.
# Replace its actions with a no-op so that `redmine:plugins:test` succeeds.
Rake::Task.define_task('redmine:plugins:test:helpers') {}
Rake.application['redmine:plugins:test:helpers'].clear_actions
