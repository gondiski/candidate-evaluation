FROM ruby:3.2.2-slim

# Install dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (for asset compilation if needed)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Set environment variables
ENV RACK_ENV=production
ENV BUNDLE_WITHOUT="development:test"

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install Ruby dependencies
RUN bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# Copy application code
COPY . .

# Precompile assets if needed
# RUN bundle exec rake assets:precompile

# Create tmp directory for reports
RUN mkdir -p tmp/reports

# Expose port
EXPOSE 9292

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9292/ || exit 1

# Start the application
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
