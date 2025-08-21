# Multi-stage build for production optimization
FROM ruby:3.2.2-alpine AS base

# Install base dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    postgresql-client \
    git \
    nodejs \
    npm \
    yarn \
    tzdata \
    gcompat \
    bash \
    curl

# Set working directory
WORKDIR /app

# Install Node 20
RUN apk add --no-cache nodejs-current npm

# Development stage
FROM base AS development

# Install additional dev dependencies
RUN apk add --no-cache \
    vim \
    less

# Install bundler
RUN gem install bundler:2.5.3

# Copy Gemfile first for better caching
COPY Gemfile* ./
RUN bundle config set --local without 'production' && \
    bundle install --jobs 4 --retry 3

# Copy package.json for Node dependencies
COPY package*.json ./
RUN npm ci || npm install

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p tmp/pids tmp/cache tmp/sockets log

# Expose ports
EXPOSE 3000 3036

# Start script for development
CMD ["bash"]

# Production stage
FROM base AS production

# Install bundler
RUN gem install bundler:2.5.3

# Copy Gemfile and install production dependencies
COPY Gemfile* ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# Copy package.json and install production dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY . .

# Precompile assets
RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile

# Create non-root user
RUN addgroup -g 1000 -S rails && \
    adduser -u 1000 -S rails -G rails && \
    chown -R rails:rails /app

# Switch to non-root user
USER rails

# Expose port
EXPOSE 3000

# Start Rails server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]