# Patch Thrift 0.8.0 Gem for Ruby 1.9.3 compatibility
if Gem.loaded_specs['thrift'].version < Gem::Version.new('0.9.0')
  module Thrift
    class HTTPClientTransport < BaseTransport
      def flush
        http = Net::HTTP.new @url.host, @url.port
        http.use_ssl = @url.scheme == "https"
        resp, data = http.post(@url.request_uri, @outbuf, @headers)
        # Was: @inbuf = StringIO.new data
        @inbuf = StringIO.new resp.body
        @outbuf = ""
      end
    end
  end
end

module ThriftHelpers
  module Connection
    class HTTP < Base
      def connect!
        parse_server(@server)
        @transport = Thrift::HTTPClientTransport.new(@server)
      end

      private
      def parse_server(server)
        uri = URI.parse(server)
        raise ArgumentError, 'Servers must start with http' unless uri.scheme =~ /^http/
        uri
      end
    end
  end
end
