# frozen_string_literal: true

# API documentation: serves the OpenAPI spec and a Swagger UI page.
# Public on purpose: it documents the contract, data still requires an API key.
class Api::V1::DocsController < ActionController::Base
  # GET /api/v1/docs
  def index
    render layout: false
  end

  # GET /api/v1/openapi
  def openapi
    send_file Rails.root.join("config", "openapi", "v1.yaml"), type: "application/yaml", disposition: "inline"
  end
end
