# Be sure to restart your server when you modify this file.
# Allow frontend (Vite dev server) to access the API.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "http://localhost:8080", "http://127.0.0.1:8080", "http://[::]:8080"

    resource "/api/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false,
      max_age: 600

    resource "/demo/*",
      headers: :any,
      methods: [:post, :options],
      credentials: false
  end
end
