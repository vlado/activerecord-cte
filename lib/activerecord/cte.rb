require "activerecord/cte/version"

module Activerecord
  module Cte
    class Error < StandardError; end
    # Your code goes here...
  end
end

ActiveSupport.on_load(:active_record) do
  module ActiveRecord
    module Querying
      delegate :with, to: :all
    end

    class Relation
      def with(opts, *rest)
        spawn.with!(opts, *rest)
      end

      def with!(opts, *rest)
        self.with_values += [opts] + rest
        self
      end

      def with_values
        @values[:with] || []
      end

      def with_values=(values)
        raise ImmutableRelation if @loaded
        @values[:with] = values
      end

      private

      def build_arel(aliases)
        arel = super(aliases)
        build_with(arel) if @values[:with]
        arel
      end

      def build_with(arel)
        return if with_values.empty?

        recursive = with_values.delete(:recursive)
        with_statements = with_values.map do |with_value|
          case with_value
          when String then Arel::Nodes::SqlLiteral.new(with_value)
          when Arel::Nodes::As then with_value
          when Array
            raise ArgumentError, "Unsupported argument type: #{with_value} #{with_value.class}" unless with_value.map(&:class).uniq == [Arel::Nodes::As]

            with_value
          when Hash then
            with_value.map do |name, value|
              table = Arel::Table.new(name)
              expression = case value
                           when String then Arel::Nodes::SqlLiteral.new("(#{value})")
                           when ActiveRecord::Relation then value.arel
                           when Arel::SelectManager, Arel::Nodes::Union then value
                           else
                             raise ArgumentError, "Unsupported argument type: #{value} #{value.class}"
              end
              Arel::Nodes::As.new(table, expression)
            end
          else
            raise ArgumentError, "Unsupported argument type: #{with_value} #{with_value.class}"
          end
        end

        if recursive
          arel.with(:recursive, with_statements)
        else
          arel.with(with_statements)
        end
      end
    end
  end
end

