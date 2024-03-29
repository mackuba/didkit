module DIDKit::Requests
  def get_response(url, options = {})
    url = URI(url) unless url.is_a?(URI)
    request_options = { use_ssl: true }

    if timeout = options[:timeout]
      request_options[:open_timeout] = timeout
      request_options[:read_timeout] = timeout
    end

    redirects = 0
    max_redirects = options[:max_redirects] || 0

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
