
module DRb

  class DRbNullSocket < DRbTCPSocket
    def self.parse_uri(uri)
      raise(DRbBadScheme, uri) unless uri =~ /^drbnull:/
      true
    end

    def self.open(uri, config)
      parse_uri(uri)
      self.new(uri, nil, config)
    end

    def self.open_server(uri, config)
      parse_uri(uri)
      self.new(uri, nil, config, true)
    end

    def self.uri_option(uri, config)
      parse_uri(uri)
      return "drbnull:", nil
    end

    def initialize(uri, soc, config={}, server_mode = false)
      super(uri, soc, config)
      @server_mode = server_mode
      @acl = nil
    end

    def close
      true
    end

    def accept
      sleep
    end

    def set_sockopt(soc)
      true
    end
  end

  DRbProtocol.add_protocol(DRbNullSocket)
end
