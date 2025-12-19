require 'json'
require 'net/http'
require 'uri'

require_relative 'errors'

module DIDKit
  module Requests
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

    def get_data(url, options = {})
      content_type = options.delete(:content_type)
      response = get_response(url, options)

      if response.is_a?(Net::HTTPSuccess) && content_type_matches(response, content_type) && (data = response.body)
        data
      else
        raise APIError.new(response)
      end
    end

    def get_json(url, options = {})
      JSON.parse(get_data(url, options))
    end

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
    def uri_origin(uri)
      uri = uri.is_a?(URI) ? uri : URI(uri)
      authority = (uri.port == uri.default_port) ? uri.host : "#{uri.host}:#{uri.port}"

      "#{uri.scheme}://#{authority}"
    end
  end
end
