FROM postgres:17-bookworm
# Preserve Cyrillic case-insensitive search when initializing the database.
RUN localedef -i uk_UA -c -f UTF-8 -A /usr/share/locale/locale.alias uk_UA.UTF-8
