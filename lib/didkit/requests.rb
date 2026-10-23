# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

require_relative 'errors'

module DIDKit

  #
  # @private
  #

  module Requests

    private

    def get_response(url, options = {})
      url = URI(url) unless url.is_a?(URI)

      timeout = options[:timeout] || 15

      request_options = {
        open_timeout: timeout,
        read_timeout: timeout
      }

      redirects = 0
      visited_urls = []
      max_redirects = options[:max_redirects] || 5

      loop do
        visited_urls << url

        request_options.update(use_ssl: (url.scheme == 'https'))

        response = Net::HTTP.start(url.hostname, url.port, request_options) do |http|
          request = Net::HTTP::Get.new(url)
          http.request(request)
        end

        if response.is_a?(Net::HTTPRedirection) && redirects < max_redirects && (location = response['Location'])
          target = URI.join(url.to_s, location)
          return response unless target.scheme == 'https' || (target.scheme == 'http' && url.scheme == 'http')

          url = target

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
      options = options.dup
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
  end
end
