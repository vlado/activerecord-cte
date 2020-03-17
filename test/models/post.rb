# frozen_string_literal: true

class Post < ActiveRecord::Base
  scope :popular_posts, -> { with(popular_posts: where("views_count > 100")).from("popular_posts AS posts") }
end
