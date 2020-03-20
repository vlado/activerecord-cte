# frozen_string_literal: true

require "test_helper"

require "models/post"

class Activerecord::CteTest < ActiveSupport::TestCase
  fixtures :posts

  def test_with_when_hash_is_passed_as_an_argument
    popular_posts = Post.where("views_count > 100")
    popular_posts_from_cte = Post.with(popular_posts: popular_posts).from("popular_posts AS posts")
    assert popular_posts.any?
    assert_equal popular_posts.to_a, popular_posts_from_cte
  end

  def test_with_when_string_is_passed_as_an_argument
    popular_posts = Post.where("views_count > 100")
    popular_posts_from_cte = Post.with("popular_posts AS (SELECT * FROM posts WHERE views_count > 100)").from("popular_posts AS posts")
    assert popular_posts.any?
    assert_equal popular_posts.to_a, popular_posts_from_cte
  end

  def test_with_when_arel_as_node_is_passed_as_an_argument
    popular_posts = Post.where("views_count > 100")

    posts_table = Arel::Table.new(:posts)
    cte_table = Arel::Table.new(:popular_posts)
    cte_select = posts_table.project(Arel.star).where(posts_table[:views_count].gt(100))
    as = Arel::Nodes::As.new(cte_table, cte_select)

    popular_posts_from_cte = Post.with(as).from("popular_posts AS posts")

    assert popular_posts.any?
    assert_equal popular_posts.to_a, popular_posts_from_cte
  end

  def test_with_when_array_of_arel_node_as_is_passed_as_an_argument
    popular_archived_posts = Post.where("views_count > 100").where(archived: true)

    posts_table = Arel::Table.new(:posts)
    first_cte_table = Arel::Table.new(:popular_posts)
    first_cte_select = posts_table.project(Arel.star).where(posts_table[:views_count].gt(100))
    first_as = Arel::Nodes::As.new(first_cte_table, first_cte_select)
    second_cte_table = Arel::Table.new(:popular_archived_posts)
    second_cte_select = first_cte_table.project(Arel.star).where(first_cte_table[:archived].eq(true))
    second_as = Arel::Nodes::As.new(second_cte_table, second_cte_select)

    popular_archived_posts_from_cte = Post.with([first_as, second_as]).from("popular_archived_posts AS posts")

    assert popular_archived_posts.any?
    assert_equal popular_archived_posts.to_a, popular_archived_posts_from_cte
  end

  def test_with_when_hash_with_multiple_elements_of_different_type_is_passed_as_an_argument
    popular_archived_posts_written_in_german = Post.where("views_count > 100").where(archived: true, language: :de)
    posts_table = Arel::Table.new(:posts)
    cte_options = {
      popular_posts: posts_table.project(Arel.star).where(posts_table[:views_count].gt(100)),
      popular_posts_written_in_german: "SELECT * FROM popular_posts WHERE language = 'de'",
      popular_archived_posts_written_in_german: Post.where(archived: true).from("popular_posts_written_in_german AS posts")
    }
    popular_archived_posts_written_in_german_from_cte = Post.with(cte_options).from("popular_archived_posts_written_in_german AS posts")
    assert popular_archived_posts_written_in_german_from_cte.any?
    assert_equal popular_archived_posts_written_in_german.to_a, popular_archived_posts_written_in_german_from_cte
  end

  def test_multiple_with_calls
    popular_archived_posts = Post.where("views_count > 100").where(archived: true)
    popular_archived_posts_from_cte = Post
      .with(archived_posts: Post.where(archived: true))
      .with(popular_archived_posts: "SELECT * FROM archived_posts WHERE views_count > 100")
      .from("popular_archived_posts AS posts")
    assert popular_archived_posts_from_cte.any?
    assert_equal popular_archived_posts.to_a, popular_archived_posts_from_cte
  end

  def test_multiple_with_calls_randomly_callled
    popular_archived_posts = Post.where("views_count > 100").where(archived: true)
    popular_archived_posts_from_cte = Post
      .with(archived_posts: Post.where(archived: true))
      .from("popular_archived_posts AS posts")
      .with(popular_archived_posts: "SELECT * FROM archived_posts WHERE views_count > 100")
    assert popular_archived_posts.any?
    assert_equal popular_archived_posts.to_a, popular_archived_posts_from_cte
  end

  def test_recursive_with_call
    posts = Arel::Table.new(:posts)
    popular_posts = Arel::Table.new(:popular_posts)
    anchor_term = posts.project(posts[:id]).where(posts[:views_count].gt(100))
    recursive_term = posts.project(posts[:id]).join(popular_posts).on(posts[:id].eq(popular_posts[:id]))

    recursive_rel = Post.with(:recursive, popular_posts: anchor_term.union(recursive_term)).from("popular_posts AS posts")
    assert_equal Post.select(:id).where("views_count > 100").to_a, recursive_rel
  end

  def test_recursive_with_query_called_as_non_recursive
    # Recursive queries works in SQLite without RECURSIVE
    return if ActiveRecord::Base.connection.adapter_name == "SQLite"

    posts = Arel::Table.new(:posts)
    popular_posts = Arel::Table.new(:popular_posts)
    anchor_term = posts.project(posts[:id]).where(posts[:views_count].gt(100))
    recursive_term = posts.project(posts[:id]).join(popular_posts).on(posts[:id].eq(popular_posts[:id]))

    non_recursive_rel = Post.with(popular_posts: anchor_term.union(recursive_term)).from("popular_posts AS posts")
    assert_raise ActiveRecord::StatementInvalid do
      non_recursive_rel.load
    end
  end

  def test_count_after_with_call
    posts_count = Post.all.count
    popular_posts_count = Post.where("views_count > 100").count
    assert posts_count > popular_posts_count
    assert popular_posts_count.positive?

    with_relation = Post.with(popular_posts: Post.where("views_count > 100"))
    assert_equal posts_count, with_relation.count
    assert_equal popular_posts_count, with_relation.from("popular_posts AS posts").count
    assert_equal popular_posts_count, with_relation.joins("JOIN popular_posts ON popular_posts.id = posts.id").count
  end

  def test_with_when_called_from_active_record_scope
    popular_posts = Post.where("views_count > 100")
    assert_equal popular_posts.to_a, Post.popular_posts
  end

  def test_with_when_invalid_params_are_passed
    assert_raise(ArgumentError) { Post.with.load }
    assert_raise(ArgumentError) { Post.with([{ popular_posts: Post.where("views_count > 100") }]).load }
    assert_raise(ArgumentError) { Post.with(popular_posts: nil).load }
    assert_raise(ArgumentError) { Post.with(popular_posts: [Post.where("views_count > 100")]).load }
  end
end
