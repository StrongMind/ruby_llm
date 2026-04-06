# frozen_string_literal: true

module RubyLLM
  # Parameter definition for Tool methods.
  class Parameter
    attr_reader :name, :type, :description, :required, :items, :properties

    def initialize(name, **options)
      @name = name
      @type = options.fetch(:type, 'string')
      @description = options.fetch(:desc, nil)
      @required = options.fetch(:required, true)
      @items = normalize_schema(options[:items])
      @properties = normalize_properties(options[:properties])
    end

    def to_schema
      {
        type: type,
        description: description,
        items: items,
        properties: properties
      }.compact
    end

    private

    def normalize_schema(schema)
      return if schema.nil?

      schema = symbolize_keys(schema)

      if shorthand_object_definition?(schema)
        {
          type: 'object',
          properties: normalize_properties(schema)
        }
      else
        {
          type: schema[:type],
          description: schema[:desc] || schema[:description],
          items: normalize_schema(schema[:items]),
          properties: normalize_properties(schema[:properties])
        }.compact
      end
    end

    def normalize_properties(properties)
      return if properties.nil?

      symbolize_keys(properties).each_with_object({}) do |(key, value), normalized|
        normalized[key] = normalize_schema(value)
      end
    end

    def shorthand_object_definition?(schema)
      schema.keys.none? { |key| %i[type items properties description desc].include?(key) }
    end

    def symbolize_keys(hash)
      hash.each_with_object({}) do |(key, value), normalized|
        normalized[key.to_sym] = value
      end
    end
  end

  # Base class for creating tools that AI models can use
  class Tool
    # Stops conversation continuation after tool execution
    class Halt
      attr_reader :content

      def initialize(content)
        @content = content
      end

      def to_s
        @content.to_s
      end
    end

    class << self
      def description(text = nil)
        return @description unless text

        @description = text
      end

      def param(name, **options)
        parameters[name] = Parameter.new(name, **options)
      end

      def parameters
        @parameters ||= {}
      end
    end

    def name
      klass_name = self.class.name
      normalized = klass_name.to_s.dup.force_encoding('UTF-8').unicode_normalize(:nfkd)
      normalized.encode('ASCII', replace: '')
                .gsub(/[^a-zA-Z0-9_-]/, '-')
                .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                .downcase
                .delete_suffix('_tool')
    end

    def description
      self.class.description
    end

    def parameters
      self.class.parameters
    end

    def call(args)
      RubyLLM.logger.debug "Tool #{name} called with: #{args.inspect}"
      result = execute(**args.transform_keys(&:to_sym))
      RubyLLM.logger.debug "Tool #{name} returned: #{result.inspect}"
      result
    end

    def execute(...)
      raise NotImplementedError, 'Subclasses must implement #execute'
    end

    protected

    def halt(message)
      Halt.new(message)
    end
  end
end
