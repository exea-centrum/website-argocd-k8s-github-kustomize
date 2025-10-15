FROM nginx:alpine

# Copy index.html
COPY index.html /usr/share/nginx/html/

# Copy static assets if they exist
RUN if ls static/*.css 2>/dev/null; then cp static/*.css /usr/share/nginx/html/; fi
RUN if ls static/*.js 2>/dev/null; then cp static/*.js /usr/share/nginx/html/; fi

# Nginx configuration
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
