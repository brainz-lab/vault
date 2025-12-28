# Production Procfile with separated worker processes
web: bin/rails server -b 0.0.0.0 -p ${PORT:-3000}
worker: bundle exec rake solid_queue:start
