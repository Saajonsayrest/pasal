# Builds the Laravel API into one image that Render can run.
FROM php:8.4-cli

# System tools, plus the PHP extension that talks to PostgreSQL.
RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip libpq-dev libzip-dev \
    && docker-php-ext-install pdo_pgsql zip \
    && rm -rf /var/lib/apt/lists/*

# Composer installs the PHP packages.
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY . .
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Render gives the port in $PORT. The tables are created on every start.
# Pushing to the live database is safe: migrate only adds what is missing.
CMD php artisan migrate --force \
    && php artisan serve --host=0.0.0.0 --port=${PORT:-10000}
