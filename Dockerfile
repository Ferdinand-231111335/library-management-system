FROM php:8.3-fpm-alpine AS base
RUN apk add --no-cache icu-dev libzip-dev libpng-dev libjpeg-turbo-dev freetype-dev su-exec \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" intl zip gd pdo_mysql bcmath exif opcache
WORKDIR /var/www/html

FROM base AS vendor
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction
COPY . .
RUN composer dump-autoload --optimize --no-dev

FROM node:20-alpine AS frontend
WORKDIR /app
COPY package*.json ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi
COPY vite.config.js ./
COPY resources ./resources
RUN npm run build

FROM base AS app
COPY --from=vendor /var/www/html /var/www/html
COPY --from=frontend /app/public/build ./public/build
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh \
 && chmod +x /usr/local/bin/entrypoint.sh \
 && mkdir -p storage/logs storage/framework/cache storage/framework/sessions \
             storage/framework/views storage/app/public bootstrap/cache \
 && chown -R www-data:www-data storage bootstrap/cache
EXPOSE 9000
ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm"]

FROM nginx:alpine AS web
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=app /var/www/html/public /var/www/html/public
RUN rm -rf /var/www/html/public/storage \
 && ln -s /var/www/html/storage/app/public /var/www/html/public/storage
EXPOSE 80