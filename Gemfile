# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in activerecord-cte.gemspec
gemspec

ACTIVE_RECORD_VERSION = ENV.fetch("ACTIVE_RECORD_VERSION", "6.1.7.2")

gem "activerecord", ACTIVE_RECORD_VERSION

gem "mysql2" if ENV["INSTALL_MYSQL_GEM"]
gem "pg" if ENV["INSTALL_PG_GEM"]

gem "sqlite3", "1.7.3"
