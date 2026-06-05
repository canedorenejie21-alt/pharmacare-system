FROM php:8.3-cli-alpine

WORKDIR /app

RUN docker-php-ext-install pdo_mysql

COPY . .

RUN chmod +x start-render.sh \
    && mkdir -p storage \
    && chmod -R 775 storage

EXPOSE 8000

CMD ["./start-render.sh"]
