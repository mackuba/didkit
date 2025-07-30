module DIDKit::Requests
  def get_response(url, options = {})
    url = URI(url) unless url.is_a?(URI)

    timeout = options[:timeout] || 15

    request_options = {
      use_ssl: true,
      open_timeout: timeout,
      read_timeout: timeout
    }

    redirects = 0
    max_redirects = options[:max_redirects] || 5

    loop do
      response = Net::HTTP.start(url.host, url.port, request_options) do |http|
        request = Net::HTTP::Get.new(url)
        http.request(request)
      end

      if response.is_a?(Net::HTTPRedirection) && redirects < max_redirects && (location = response['Location'])
        url = URI(location.include?('://') ? location : (url.origin + location))
        redirects += 1
      else
        return response
      end
    end
  end
end
