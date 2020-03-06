# frozen_string_literal: true

require "test_helper"

require "models/post"

class Activerecord::CteTest < ActiveSupport::TestCase
  fixtures :posts

  def test_with_when_hash_is_passed_as_an_argument
    popular_posts = Post.where("views_count > 100")
    popular_posts_from_cte = Post.with(popular_posts: popular_posts).from("popular_posts AS posts")
    assert_equal popular_posts.to_a, popular_posts_from_cte
    assert_equal 2, popular_posts_from_cte.size
  end

  def test_with_when_string_is_passed_as_an_argument
    popular_posts = Post.where("views_count > 100")
    popular_posts_from_cte = Post.with("popular_posts AS (SELECT * FROM posts WHERE views_count > 100)").from("popular_posts AS posts")
    assert_equal popular_posts.to_a, popular_posts_from_cte
    assert_equal 2, popular_posts_from_cte.size
  end

  def test_with_when_arel_as_node_is_passed_as_an_argument
    popular_posts = Post.where("views_count > 100")

    posts_table = Arel::Table.new(:posts)
    cte_table = Arel::Table.new(:popular_posts)
    cte_select = posts_table.project(Arel.star).where(posts_table[:views_count].gt(100))
    as = Arel::Nodes::As.new(cte_table, cte_select)

    popular_posts_from_cte = Post.with(as).from("popular_posts AS posts")
    assert_equal popular_posts.to_a, popular_posts_from_cte
    assert_equal 2, popular_posts_from_cte.size
  end
end
