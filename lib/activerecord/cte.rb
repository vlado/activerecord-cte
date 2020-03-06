# frozen_string_literal: true

require "activerecord/cte/version"

module Activerecord
  module Cte
    class Error < StandardError; end
    # Your code goes here...
  end
end

ActiveSupport.on_load(:active_record) do
  require "activerecord/cte/core_ext"
end
