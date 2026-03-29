# SimpleCov を使う場合は RUBYOPT でプリロードしてください（test/simplecov_start.rb 参照）。
# ここでは二重起動を避けるため、未起動時のみ起動します。
unless defined?(SimpleCov) && SimpleCov.running
  begin
    require 'simplecov'
    require_relative 'simplecov_start'
  rescue LoadError
    # simplecov がない場合はスキップ
  end
end

require File.expand_path('../../../../test/test_helper', __FILE__)
require_relative '../lib/redmine_issue_references'
