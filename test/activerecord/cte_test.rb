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
    # Guard can be removed when new version that includes https://github.com/rails/rails/pull/42563 is released and configured in test matrix
    return if ActiveRecord.version == Gem::Version.create("6.1.7.2")

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

  def test_recursive_with_call_union_all
    posts = Arel::Table.new(:posts)
    popular_posts = Arel::Table.new(:popular_posts)
    anchor_term = posts.project(posts[:id]).where(posts[:views_count].gt(100))
    recursive_term = posts.project(posts[:id]).join(popular_posts).on(posts[:id].eq(popular_posts[:id]))

    recursive_rel = Post.with(:recursive, popular_posts: anchor_term.union(:all, recursive_term)).from("popular_posts AS posts")
    assert_includes recursive_rel.to_sql, "UNION ALL"
  end

  def test_recursive_is_preserved_on_multiple_with_calls
    posts = Arel::Table.new(:posts)
    popular_posts = Arel::Table.new(:popular_posts)
    anchor_term = posts.project(posts[:id], posts[:archived]).where(posts[:views_count].gt(100))
    recursive_term = posts.project(posts[:id], posts[:archived]).join(popular_posts).on(posts[:id].eq(popular_posts[:id]))

    recursive_rel = Post.with(:recursive, popular_posts: anchor_term.union(recursive_term)).from("popular_posts AS posts")

    assert_equal Post.select(:id).where("views_count > 100").to_a, recursive_rel
    assert_equal Post.select(:id).where("views_count > 100").where(archived: true).to_a, recursive_rel.where(archived: true)
  end

  def test_multiple_with_calls_with_recursive_and_non_recursive_queries
    posts = Arel::Table.new(:posts)
    popular_posts = Arel::Table.new(:popular_posts)
    anchor_term = posts.project(posts[:id]).where(posts[:views_count].gt(100))
    recursive_term = posts.project(posts[:id]).join(popular_posts).on(posts[:id].eq(popular_posts[:id]))

    archived_popular_posts = Post
      .with(archived_posts: Post.where(archived: true))
      .with(:recursive, popular_posts: anchor_term.union(recursive_term))
      .from("popular_posts AS posts")
      .joins("INNER JOIN archived_posts ON archived_posts.id = posts.id")

    assert archived_popular_posts.to_sql.start_with?("WITH RECURSIVE ")
    assert_equal posts(:two, :three).pluck(:id).sort, archived_popular_posts.to_a.pluck(:id).sort
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

  def test_with_when_merging_relations
    most_popular = Post.with(most_popular: Post.where("views_count >= 100").select("id as post_id")).joins("join most_popular on most_popular.post_id = posts.id")
    least_popular = Post.with(least_popular: Post.where("views_count <= 400").select("id as post_id")).joins("join least_popular on least_popular.post_id = posts.id")
    merged = most_popular.merge(least_popular)

    assert_equal(1, merged.size)
    assert_equal(123, merged[0].views_count)
  end

  def test_with_when_merging_relations_with_identical_with_names_and_identical_queries
    most_popular1 = Post.with(most_popular: Post.where("views_count >= 100"))
    most_popular2 = Post.with(most_popular: Post.where("views_count >= 100"))

    merged = most_popular1.merge(most_popular2).from("most_popular as posts")

    assert_equal posts(:two, :three, :four).sort, merged.sort
  end

  def test_with_when_merging_relations_with_a_mixture_of_strings_and_relations
    most_popular1 = Post.with(most_popular: Post.where(views_count: 456))
    most_popular2 = Post.with(most_popular: Post.where("views_count = 456"))

    merged = most_popular1.merge(most_popular2)

    assert_raise ActiveRecord::StatementInvalid do
      merged.load
    end
  end

  def test_with_when_merging_relations_with_identical_with_names_and_different_queries
    most_popular1 = Post.with(most_popular: Post.where("views_count >= 100"))
    most_popular2 = Post.with(most_popular: Post.where("views_count <= 100"))

    merged = most_popular1.merge(most_popular2)

    assert_raise ActiveRecord::StatementInvalid do
      merged.load
    end
  end

  def test_with_when_merging_relations_with_recursive_and_non_recursive_queries
    non_recursive_rel = Post.with(archived_posts: Post.where(archived: true))

    posts = Arel::Table.new(:posts)
    popular_posts = Arel::Table.new(:popular_posts)
    anchor_term = posts.project(posts[:id]).where(posts[:views_count].gt(100))
    recursive_term = posts.project(posts[:id]).join(popular_posts).on(posts[:id].eq(popular_posts[:id]))
    recursive_rel = Post.with(:recursive, popular_posts: anchor_term.union(recursive_term))

    merged_rel = non_recursive_rel
      .merge(recursive_rel)
      .from("popular_posts AS posts")
      .joins("INNER JOIN archived_posts ON archived_posts.id = posts.id")

    assert merged_rel.to_sql.start_with?("WITH RECURSIVE ")
    assert_equal posts(:two, :three).pluck(:id).sort, merged_rel.to_a.pluck(:id).sort
  end

  def test_update_all_works_as_expected
    Post.with(most_popular: Post.where("views_count >= 100")).update_all(views_count: 123)
    assert_equal [123], Post.pluck(Arel.sql("DISTINCT views_count"))
  end

  def test_delete_all_works_as_expected
    Post.with(most_popular: Post.where("views_count >= 100")).delete_all
    assert_equal 0, Post.count
  end
end
