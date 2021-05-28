# frozen_string_literal: true

module ActiveRecord
  module Querying
    delegate :with, to: :all
  end
  
  module WithMerger
    def normal_values
      super + %i[with]
    end

    def merge
      super
      merge_withs
      relation
    end

    private

    def merge_withs
      other_values = other.with_values.reject { |value| relation.with_values.include?(value) }
      relation.with!(*other_values) if other_values.any?
    end
  end

  class Relation
    class Merger
      prepend WithMerger
    end

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

    def build_with(arel) # rubocop:disable Metrics/MethodLength
      return if with_values.empty?

      recursive = with_values.delete(:recursive)
      with_statements = with_values.map do |with_value|
        case with_value
        when String then Arel::Nodes::SqlLiteral.new(with_value)
        when Arel::Nodes::As then with_value
        when Hash then build_with_value_from_hash(with_value)
        when Array then build_with_value_from_array(with_value)
        else
          raise ArgumentError, "Unsupported argument type: #{with_value} #{with_value.class}"
        end
      end

      recursive ? arel.with(:recursive, with_statements) : arel.with(with_statements)
    end

    def build_with_value_from_array(array)
      unless array.map(&:class).uniq == [Arel::Nodes::As]
        raise ArgumentError, "Unsupported argument type: #{array} #{array.class}"
      end

      array
    end

    def build_with_value_from_hash(hash) # rubocop:disable Metrics/MethodLength
      hash.map do |name, value|
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
    end
  end
end
