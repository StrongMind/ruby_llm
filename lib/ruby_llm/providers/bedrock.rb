# frozen_string_literal: true

require 'openssl'
require 'time'

module RubyLLM
  module Providers
    # AWS Bedrock API integration. Handles chat completion and streaming
    # for Claude models.
    module Bedrock
      extend Provider
      extend Bedrock::Chat
      extend Bedrock::Streaming
      extend Bedrock::Models
      extend Bedrock::Signing

      # This provider currently only supports Anthropic models, so the tools/media implementation is shared
      extend Anthropic::Media
      extend Anthropic::Tools

      module_function

      def api_base(config)
        @api_base ||= "https://bedrock-runtime.#{config.bedrock_region}.amazonaws.com"
      end

      def post(connection, config, url, payload)
        signature = sign_request("#{connection.url_prefix}#{url}", config:, payload:)
        connection.post url, payload do |req|
          req.headers.merge! build_headers(signature.headers, streaming: block_given?)

          yield req if block_given?
        end
      end

      def parse_error(response) # rubocop:disable Metrics/MethodLength
        return if response.body.empty?

        body = try_parse_json(response.body)
        case body
        when Hash
          body['message']
        when Array
          body.map do |part|
            part['message']
          end.join('. ')
        else
          body
        end
      end

      def sign_request(url, config:, method: :post, payload: nil)
        signer = create_signer(config)
        request = build_request(url, config:, method:, payload:)
        signer.sign_request(request)
      end

      def create_signer(config)
        Signing::Signer.new({
                              access_key_id: config.bedrock_api_key,
                              secret_access_key: config.bedrock_secret_key,
                              session_token: config.bedrock_session_token,
                              region: config.bedrock_region,
                              service: 'bedrock'
                            })
      end

      def build_request(url, config:, method: :post, payload: nil)
        {
          connection: connection(config),
          http_method: method,
          url: url || completion_url,
          body: payload ? JSON.generate(payload, ascii_only: false) : nil
        }
      end

      def build_headers(signature_headers, streaming: false)
        accept_header = streaming ? 'application/vnd.amazon.eventstream' : 'application/json'

        signature_headers.merge(
          'Content-Type' => 'application/json',
          'Accept' => accept_header
        )
      end

      def capabilities
        Bedrock::Capabilities
      end

      def slug
        'bedrock'
      end

      def configuration_requirements
        %i[bedrock_api_key bedrock_secret_key bedrock_region]
      end
    end
  end
end
