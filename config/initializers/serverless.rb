class AutoDisconnect
  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  ensure
    # Per Rails 6+
    ActiveRecord::Base.connection_pool.release_connection

    # Oppure, per disconnettere completamente:
    # ActiveRecord::Base.connection_pool.disconnect!
  end
end

Rails.application.config.middleware.use AutoDisconnect if ENV["RAILS_SERVERLESS_MODE"] == "enabled"
