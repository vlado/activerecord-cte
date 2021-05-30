# ActiveRecord::Cte

Adds Common Table Expression support to ActiveRecord (Rails).

It adds `.with` query method and makes it super easy to build and chain complex CTE queries. Let's explain it using simple example.

```ruby
Post.with(
  posts_with_comments: Post.where("comments_count > ?", 0),
  posts_with_tags: Post.where("tags_count > ?", 0)
)
```

Will return `ActiveRecord::Relation` and will generate SQL like this.

```SQL
WITH posts_with_comments AS (
  SELECT * FROM posts WHERE (comments_count > 0)
), posts_with_tags AS (
  SELECT * FROM posts WHERE (tags_count > 0)
)
SELECT * FROM posts
```

Without this gem you would need to use `Arel` directly.

```ruby
post_with_comments_table = Arel::Table.new(:posts_with_comments)
post_with_comments_expression = Post.arel_table.where(posts_with_comments_table[:comments_count].gt(0))
post_with_tags_table = Arel::Table.new(:posts_with_tags)
post_with_tags_expression = Post.arel_table.where(posts_with_tags_table[:tags_count].gt(0))

Post.all.arel.with([
  Arel::Node::As.new(posts_with_comments_table, posts_with_comments_expression),
  Arel::Node::As.new(posts_with_tags_table, posts_with_tags_expression)
])
```

Instead of Arel you could also pass raw SQL string but either way you will NOT get `ActiveRecord::Relation` and
you will not be able to chain them further, cache them easily, call `count` and other aggregates on them, ...

## Installation

Add this line to your application's Gemfile:

```ruby
gem "activerecord-cte"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install activerecord-cte

## Usage

### Hash arguments

Easiest way to build the `WITH` query is to pass the `Hash` where keys are used as names of the tables and values are used to
generate the SQL. You can pass `ActiveRecord::Relation`, `String` or `Arel::Nodes::As` node.

```ruby
Post.with(
  posts_with_comments: Post.where("comments_count > ?", 0),
  posts_with_tags: "SELECT * FROM posts WHERE tags_count > 0"
)
# WITH posts_with_comments AS (
#  SELECT * FROM posts WHERE (comments_count > 0)
# ), posts_with_tags AS (
# SELECT * FROM posts WHERE (tags_count > 0)
# )
# SELECT * FROM posts
```

### SQL string

You can also pass complete CTE as a single SQL string

```ruby
Post.with("posts_with_tags AS (SELECT * FROM posts WHERE tags_count > 0)")
# WITH posts_with_tags AS (
#   SELECT * FROM posts WHERE (tags_count > 0)
# )
# SELECT * FROM posts
```

### Arel Nodes

If you already have `Arel::Node::As` node you can just pass it as is

```ruby
posts_table = Arel::Table.new(:posts)
cte_table = Arel::Table.new(:posts_with_tags)
cte_select = posts_table.project(Arel.star).where(posts_table[:tags_count].gt(100))
as = Arel::Nodes::As.new(cte_table, cte_select)

Post.with(as)
# WITH posts_with_tags AS (
#   SELECT * FROM posts WHERE (tags_count > 0)
# )
# SELECT * FROM posts
```

You can also pass array of Arel Nodes

```ruby
posts_table = Arel::Table.new(:posts)

with_tags_table = Arel::Table.new(:posts_with_tags)
with_tags_select = posts_table.project(Arel.star).where(posts_table[:tags_count].gt(100))
as_posts_with_tags = Arel::Nodes::As.new(with_tags_table, with_tags_select)

with_comments_table = Arel::Table.new(:posts_with_comments)
with_comments_select = posts_table.project(Arel.star).where(posts_table[:comments_count].gt(100))
as_posts_with_comments = Arel::Nodes::As.new(with_comments_table, with_comments_select)

Post.with([as_posts_with_tags, as_posts_with_comments])
# WITH posts_with_comments AS (
#  SELECT * FROM posts WHERE (comments_count > 0)
# ), posts_with_tags AS (
# SELECT * FROM posts WHERE (tags_count > 0)
# )
# SELECT * FROM posts
```

### Taking it further

As you probably noticed from the examples above `.with` is only a half of the equation. Once we have CTE results we also need to do the select on them somehow.

You can write custom `FROM` that will alias your CTE table to the table ActiveRecord expects by default (`Post -> posts`) for example.

```ruby
Post
  .with(posts_with_tags: "SELECT * FROM posts WHERE tags_count > 0")
  .from("posts_with_tags AS posts")
# WITH posts_with_tags AS (
#   SELECT * FROM posts WHERE (tags_count > 0)
# )
# SELECT * FROM posts_with_tags AS posts

Post
  .with(posts_with_tags: "SELECT * FROM posts WHERE tags_count > 0")
  .from("posts_with_tags AS posts")
  .count

# WITH posts_with_tags AS (
#   SELECT * FROM posts WHERE (tags_count > 0)
# )
# SELECT COUNT(*) FROM posts_with_tags AS posts
```

Another option would be to use join

```ruby
Post
  .with(posts_with_tags: "SELECT * FROM posts WHERE tags_count > 0")
  .joins("JOIN posts_with_tags ON posts_with_tags.id = posts.id")
# WITH posts_with_tags AS (
#   SELECT * FROM posts WHERE (tags_count > 0)
# )
# SELECT * FROM posts JOIN posts_with_tags ON posts_with_tags.id = posts.id
```

There are other options also but that heavily depends on your use case and is out of scope of this README :)

### Recursive CTE

Recursive queries are also supported `Post.with(:recursive, popular_posts: "... union to get popular posts ...")`.

```ruby
posts = Arel::Table.new(:posts)
top_posts = Arel::Table.new(:top_posts)

anchor_term = posts.project(posts[:id]).where(posts[:comments_count].gt(1))
recursive_term = posts.project(posts[:id]).join(top_posts).on(posts[:id].eq(top_posts[:id]))

Post.with(:recursive, top_posts: anchor_term.union(recursive_term)).from("top_posts AS posts")
# WITH RECURSIVE "popular_posts" AS (
#   SELECT "posts"."id" FROM "posts" WHERE "posts"."comments_count" > 0 UNION SELECT "posts"."id" FROM "posts" INNER JOIN "popular_posts" ON "posts"."id" = "popular_posts"."id" ) SELECT "posts".* FROM popular_posts AS posts
```

## Issues

Please note that `update_all` and `delete_all` methods are not implemented and will not work as expected. I tried to implement them and was succesfull
but the "monkey patching" level was so high that I decided not to keep the implementation.

If my [Pull Request](https://github.com/rails/rails/pull/37944) gets merged adding them to Rails direcly will be easy and since I did not need them yet
I decided to wait a bit :)

## Development

### Setup

After checking out the repo, run `bin/setup` to install dependencies.

### Running tests

Run `rake test` to run the tests using SQLite adapter and latest version on Rails.

To run tests using all supportted database adapters and ActiveRecord versions run `rake test:matrix`. This will build Docker image with all dependencies and run alll tests in it. See `bin/test` for more info.

### Console

You can run `bin/console` for an interactive prompt that will allow you to experiment.

### Other

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/vlado/activerecord-cte. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Activerecord::Cte project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/activerecord-cte/blob/master/CODE_OF_CONDUCT.md).
