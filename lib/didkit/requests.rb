require 'json'
require 'net/http'
require 'uri'

require_relative 'errors'

module DIDKit
  # HTTP helper methods for fetching data from DID-related endpoints.
  module Requests
    # Fetch an HTTP response with redirects.
    #
    # @param url [String, URI] URL to request.
    # @param options [Hash] request options.
    # @option options [Integer] :timeout request timeout in seconds.
    # @option options [Integer] :max_redirects maximum redirects to follow.
    # @return [Net::HTTPResponse] the response returned by Net::HTTP.
    def get_response(url, options = {})
      url = URI(url) unless url.is_a?(URI)

      timeout = options[:timeout] || 15

      request_options = {
        use_ssl: true,
        open_timeout: timeout,
        read_timeout: timeout
      }

      redirects = 0
      visited_urls = []
      max_redirects = options[:max_redirects] || 5

      loop do
        visited_urls << url

        response = Net::HTTP.start(url.host, url.port, request_options) do |http|
          request = Net::HTTP::Get.new(url)
          http.request(request)
        end

        if response.is_a?(Net::HTTPRedirection) && redirects < max_redirects && (location = response['Location'])
          url = URI(location.include?('://') ? location : (uri_origin(url) + location))

          if visited_urls.include?(url)
            return response
          else
            redirects += 1
          end
        else
          return response
        end
      end
    end

    # Fetch response body data with optional content-type checking.
    #
    # @param url [String, URI] URL to request.
    # @param options [Hash] request options.
    # @option options [Integer] :timeout request timeout in seconds.
    # @option options [Integer] :max_redirects maximum redirects to follow.
    # @option options [String, Regexp, Symbol, nil] :content_type expected content type.
    # @return [String] response body.
    # @raise [APIError] when the response status or content type is invalid.
    def get_data(url, options = {})
      content_type = options.delete(:content_type)
      response = get_response(url, options)

      if response.is_a?(Net::HTTPSuccess) && content_type_matches(response, content_type) && (data = response.body)
        data
      else
        raise APIError.new(response)
      end
    end

    # Fetch and parse JSON from a URL.
    #
    # @param url [String, URI] URL to request.
    # @param options [Hash] request options.
    # @return [Object] parsed JSON.
    # @raise [APIError] when the response status or content type is invalid.
    # @raise [JSON::ParserError] when the response body is not valid JSON.
    def get_json(url, options = {})
      JSON.parse(get_data(url, options))
    end

    # Check if the response content type matches the expected type.
    #
    # @param response [Net::HTTPResponse] response to check.
    # @param expected_type [String, Regexp, Symbol, nil] expected content type.
    # @return [Boolean] whether the content type matches.
    # @raise [ArgumentError] when expected_type is unsupported.
    def content_type_matches(response, expected_type)
      content_type = response['Content-Type']

      case expected_type
      when String
        content_type == expected_type
      when Regexp
        content_type =~ expected_type
      when :json
        content_type =~ /^application\/json(;.*)?$/
      when nil
        true
      else
        raise ArgumentError, "Invalid expected_type: #{expected_type.inspect}"
      end
    end

    # backported from https://github.com/ruby/uri/pull/30/files for older Rubies
    # Build an origin string for a URI.
    #
    # @param uri [String, URI] URI to normalize.
    # @return [String] scheme/host/port origin.
    def uri_origin(uri)
      uri = uri.is_a?(URI) ? uri : URI(uri)
      authority = (uri.port == uri.default_port) ? uri.host : "#{uri.host}:#{uri.port}"

      "#{uri.scheme}://#{authority}"
    end
  end
end
