# frozen_string_literal: true

require "test_helper"

class Api::V1::DocsTest < ApiIntegrationTest
  test "docs and openapi are public" do
    get "/api/v1/docs"
    assert_response :success
    assert_includes @response.body, "swagger-ui"

    get "/api/v1/openapi"
    assert_response :success
  end

  test "openapi spec documents every api route" do
    spec = YAML.safe_load_file(Rails.root.join("config", "openapi", "v1.yaml"))

    Rails.application.routes.routes.each do |route|
      path = route.path.spec.to_s
      next unless path.start_with?("/api/v1/")
      next if path.include?("/docs") || path.include?("/openapi")

      # /api/v1/tasks/:id(.:format) -> /tasks/{id}
      spec_path = path.sub("/api/v1", "").sub("(.:format)", "").gsub(/:(\w+)/) { "{#{$1}}" }
      verb = route.verb.downcase
      # Rails resources map update to both PATCH and PUT: the spec documents PATCH
      verb = "patch" if verb == "put"

      assert spec["paths"].key?(spec_path), "Route #{path} missing from openapi spec"
      assert spec["paths"][spec_path].key?(verb), "Verb #{verb.upcase} for #{spec_path} missing from openapi spec"
    end
  end
end
