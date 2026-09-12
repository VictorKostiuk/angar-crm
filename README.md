# Angar CRM

Rails 8.1, Ruby 3.4.10, PostgreSQL 17, Tailwind and Hotwire.
Install Ruby with mise, PostgreSQL with the `uk_UA.UTF-8` locale, and libvips
for photo processing. Run `bin/setup` to prepare the database and start locally.

Run `bin/rails test` and `bin/rails test:system` (Chrome required), or `bin/ci`
for the full checks. `bin/rails db:seed` initializes missing owners and catalog
entries. Development-only initial passwords default to `password123`; existing
accounts and edited catalog prices are preserved. Production requires explicit
seed-password environment variables.

See [deployment instructions](docs/DEPLOYMENT.md) for the shared Netcup server,
GitHub releases, production configuration, backups and recovery.
