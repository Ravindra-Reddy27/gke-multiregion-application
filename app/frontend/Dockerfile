FROM nginx:alpine

COPY index.html /usr/share/nginx/html/
# FIX: Copy to the templates directory instead of conf.d
COPY nginx.conf /etc/nginx/templates/default.conf.template

EXPOSE 80