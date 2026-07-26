class ApplicationController < ActionController::API
  before_action :authenticate!

  private

  def authenticate!
    configured = ENV["API_AUTH_TOKEN"]
    if configured.blank?
      render json: { error: "API_AUTH_TOKEN not configured" }, status: :internal_server_error
      return
    end

    provided = request.headers["Authorization"].to_s.delete_prefix("Bearer ")
    unless ActiveSupport::SecurityUtils.secure_compare(provided, configured)
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
