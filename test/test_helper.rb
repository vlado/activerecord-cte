# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "active_record"
require "active_record/fixtures"
require "active_support/test_case"
require "dotenv"

require "activerecord/cte"

require "active_support/testing/autorun"

Dotenv.load
ActiveRecord::Base.establish_connection

ActiveSupport.on_load(:active_support_test_case) do
  include ActiveRecord::TestFixtures
  self.fixture_path = "test/fixtures/"

  ActiveSupport::TestCase.test_order = :random
end

ActiveRecord::Schema.define do
  create_table :posts, force: true do |t|
    t.integer :views_count
    t.timestamps
  end
end
