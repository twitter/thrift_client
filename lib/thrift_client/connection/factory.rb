module ThriftConnection
  class Factory
    def self.create(transport, transport_wrapper, server, timeout)
      if transport == Thrift::HTTPClientTransport
        ThriftConnection::HTTP.new(transport, transport_wrapper, server, timeout)
      else
        ThriftConnection::Socket.new(transport, transport_wrapper, server, timeout)
      end
    end
  end
end
