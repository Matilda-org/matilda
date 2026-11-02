# Lets a tool class declare several functions with define_function/property
# and exposes each one to RubyLLM as its own tool, bound to the instance so the
# functions share its state (the user, the proposals).
module VectorsearchTools::Definition
  extend ActiveSupport::Concern

  class PropertiesBuilder
    def initialize(schema)
      @schema = schema
    end

    def property(name, type:, description: nil, required: false, enum: nil)
      @schema[:properties][name] = { type: type, description: description, enum: enum }.compact
      @schema[:required] << name.to_s if required
    end
  end

  class_methods do
    def functions
      @functions ||= {}
    end

    def define_function(name, description:, &properties)
      schema = { type: "object", properties: {}, required: [] }
      PropertiesBuilder.new(schema).instance_eval(&properties) if properties
      functions[name] = { description: description, schema: schema }
    end
  end

  def ruby_llm_tools
    owner = self
    self.class.functions.map do |name, function|
      Class.new(RubyLLM::Tool) do
        define_singleton_method(:tool_name) { name.to_s }
        description function[:description]
        parameters function[:schema]

        # A failing function answers the model with the error instead of
        # breaking the whole chat turn, so the model can tell the user.
        define_method(:execute) do |**data|
          owner.public_send(name, data)
        rescue StandardError => e
          Rails.logger.error("VectorsearchTools #{name}: #{e.class}: #{e.message}")
          { error: "The #{name} tool failed: #{e.message}" }
        end
      end.new
    end
  end
end
