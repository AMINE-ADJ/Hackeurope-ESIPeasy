FROM ruby:3.0.2-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential libsqlite3-dev git curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /rails

COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

COPY . .

# Prepare database (create + migrate + seed)
RUN RAILS_ENV=production SECRET_KEY_BASE=dummy \
    bundle exec rails db:prepare 2>/dev/null || true

EXPOSE 3000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
