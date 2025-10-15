FROM nginx:alpine

# Skopiuj pliki strony
COPY index.html /usr/share/nginx/html/
COPY *.css /usr/share/nginx/html/ 2>/dev/null || true
COPY *.js /usr/share/nginx/html/ 2>/dev/null || true

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
