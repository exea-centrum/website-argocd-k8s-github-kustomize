FROM nginx:alpine

# Skopiuj całą zawartość bieżącego katalogu
COPY . /usr/share/nginx/html/

# Konfiguracja nginx
RUN echo 'server { \
    listen 80; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html; \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
