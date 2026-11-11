#!/bin/sh
set -e

if [ "$1" = "php-fpm" ]; then
    echo ">> Menjalankan migrasi database..."
    su-exec www-data php artisan migrate --force
    su-exec www-data php artisan config:cache
    su-exec www-data php artisan view:cache
fi

exec "$@"