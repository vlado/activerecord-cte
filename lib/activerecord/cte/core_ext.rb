# frozen_string_literal: true

module ActiveRecord
  module Querying
    delegate :with, to: :all
  end

  class Relation
    def delete_all
      invalid_methods = INVALID_METHODS_FOR_DELETE_ALL.select do |method|
        value = @values[method]
        method == :distinct ? value : value&.any?
      end
      if invalid_methods.any?
        raise ActiveRecordError.new("delete_all doesn't support #{invalid_methods.join(', ')}")
      end

      if eager_loading?
        relation = apply_join_dependency
        return relation.delete_all
      end

      stmt = Arel::DeleteManager.new
      stmt.from(arel.join_sources.empty? ? table : arel.source)
      stmt.key = arel_attribute(primary_key)
      stmt.take(arel.limit)
      stmt.offset(arel.offset)
      stmt.order(*arel.orders)
      stmt.wheres = arel.constraints
      stmt.with = arel.ast.with

      affected = @klass.connection.delete(stmt, "#{@klass} Destroy")

      reset
      affected
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

Arel::TreeManager.class_eval do
  def with=(expr)
    @ast.with = expr
  end
end

Arel::Nodes::DeleteStatement.class_eval do
  attr_accessor :with

  def hash
    [self.class, @left, @right, @orders, @limit, @offset, @key, @with].hash
  end

  def eql?(other)
    self.class == other.class &&
      self.left == other.left &&
      self.right == other.right &&
      self.orders == other.orders &&
      self.limit == other.limit &&
      self.offset == other.offset &&
      self.key == other.key &&
      self.with == other.with
  end
  alias :== :eql?
end

Arel::Visitors::ToSql.class_eval do
  def prepare_update_statement(o)
    if o.with || (o.key && (has_limit_or_offset_or_orders?(o) || has_join_sources?(o)))
      stmt = o.clone
      stmt.limit = nil
      stmt.offset = nil
      stmt.orders = []
      stmt.wheres = [Arel::Nodes::In.new(o.key, [build_subselect(o.key, o)])]
      stmt.relation = o.relation.left if has_join_sources?(o)
      stmt
    else
      o
    end
  end
  alias :prepare_delete_statement :prepare_update_statement

  def build_subselect(key, o)
    stmt             = Arel::Nodes::SelectStatement.new
    core             = stmt.cores.first
    core.froms       = o.relation
    core.wheres      = o.wheres
    core.projections = [key]
    stmt.limit       = o.limit
    stmt.offset      = o.offset
    stmt.orders      = o.orders
    stmt.with        = o.with
    stmt
  end
end
