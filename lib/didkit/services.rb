module DIDKit
  module Services
    def get_service(key, type)
      @services&.detect { |s| s.key == key && s.type == type }
    end

    def pds_endpoint
      @pds_endpoint ||= get_service('atproto_pds', 'AtprotoPersonalDataServer')&.endpoint
    end

    def labeler_endpoint
      @labeler_endpoint ||= get_service('atproto_labeler', 'AtprotoLabeler')&.endpoint
    end

    def pds_host
      pds_endpoint&.then { |x| URI(x).host }
    end

    def labeler_host
      labeler_endpoint&.then { |x| URI(x).host }
    end
  end
end
