# frozen_string_literal: true

require "hanami/utils/hash"
require "hanami/middleware/error"
require_relative "body_parser/class_interface"

module Hanami
  module Middleware
    # @since 1.3.0
    # @api private
    class BodyParser
      # @since 1.3.0
      # @api private
      CONTENT_TYPE = "CONTENT_TYPE"

      # @since 1.3.0
      # @api private
      MEDIA_TYPE_MATCHER = /\s*[;,]\s*/

      # @since 1.3.0
      # @api private
      RACK_INPUT = "rack.input"

      # @since 1.3.0
      # @api private
      ROUTER_PARAMS = "router.params"

      # @api private
      ROUTER_PARSED_BODY = "router.parsed_body"

      # @api private
      FALLBACK_KEY = "_"

      extend ClassInterface

      def initialize(app, parsers)
        @app = app
        @parsers = build_parsers(parsers)
      end

      def call(env)
        body = env[RACK_INPUT].read
        return @app.call(env) if body.empty?

        env[RACK_INPUT].rewind # somebody might try to read this stream

        if (parser = @parsers[media_type(env)])
          env[ROUTER_PARSED_BODY] = parser.parse(body)
          env[ROUTER_PARAMS] = _symbolize(env[ROUTER_PARSED_BODY])
        end

        @app.call(env)
      end

      private

      def build_parsers(parser_names)
        parser_names = Array(parser_names)
        return {} if parser_names.empty?

        parser_names.each_with_object({}) do |name, parsers|
          parser = self.class.for(name)

          parser.mime_types.each do |mime|
            parsers[mime] = parser
          end
        end
      end

      # @api private
      def _symbolize(body)
        if body.is_a?(Hash)
          Utils::Hash.deep_symbolize(body)
        else
          { FALLBACK_KEY => body }
        end
      end

      # @api private
      def _parse(env, body)
        @parsers[
          media_type(env)
        ].parse(body)
      end

      # @api private
      def media_type(env)
        ct = content_type(env)
        return unless ct

        ct.split(MEDIA_TYPE_MATCHER, 2).first.downcase
      end

      # @api private
      def content_type(env)
        content_type = env[CONTENT_TYPE]
        content_type.nil? || content_type.empty? ? nil : content_type
      end
    end
  end
end
