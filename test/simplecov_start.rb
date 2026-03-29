# frozen_string_literal: true

# このファイルは RUBYOPT でプリロードされることを想定しています。
# test/test_helper.rb より先に SimpleCov を起動することで、
# Redmine がプラグインファイルを require する前にインスツルメントされます。
#
# 使用方法（テスト実行コマンド）:
#   RUBYOPT="-r $(pwd)/test/simplecov_start.rb" \
#     bundle exec rake redmine:plugins:test NAME=redmine_issue_references RAILS_ENV=test

return if defined?(SimpleCov) && SimpleCov.running

require 'rubygems'
# bundler/setup で Gemfile の load path を確立してから simplecov を require する
begin
  require 'bundler/setup'
rescue LoadError
  # bundler がない環境ではスキップ
end
require 'simplecov'

SimpleCov.start do
  # __dir__ は /var/lib/redmine/plugins/redmine_issue_references/test になる
  plugin_root = File.expand_path('..', __dir__)

  track_files "#{plugin_root}/{app,lib}/**/*.rb"

  # テスト・マイグレーション・スクリプトは除外
  add_filter { |src| !src.filename.start_with?(plugin_root) }
  add_filter '/test/'
  add_filter '/db/'
  add_filter '/scripts/'

  add_group 'Models',      'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Helpers',     'app/helpers'
  add_group 'Lib',         'lib/redmine_issue_references'
  add_group 'Parsers',     'lib/redmine_issue_references/parsers'

  coverage_dir '/var/lib/redmine/public/coverage'
end
