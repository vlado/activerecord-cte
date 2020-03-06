# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in activerecord-cte.gemspec
gemspec

ACTIVE_RECORD_VERSION = ENV.fetch("ACTIVE_RECORD_VERSION") { "6.0" }

eval_gemfile "gemfiles/ar-#{ACTIVE_RECORD_VERSION}.gemfile"
