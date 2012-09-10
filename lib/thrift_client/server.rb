require 'thrift_client/connection'

module ThriftHelpers
  class Server
    class ServerMarkedDown < StandardError; end

    def initialize(connection_string)
      @connection_string = connection_string
      @connection = nil
      @marked_down_til = nil
    end

    def open(trans, wrap, timeout)
      if down?
        raise ServerMarkedDown, "marked down until #{@marked_down_til}"
      end

      @connection = Connection::Factory.create(trans, wrap, @connection_string, timeout)
      @connection.connect!
      self
    end

    def close
      @connection.close rescue nil #TODO
      @connection = nil
    end

    def transport
      @connection.transport
    end

    def mark_down!(til)
      @marked_down_til = Time.now + til
    end

    def up?
      !down?
    end

    def down?
      @marked_down_til && @marked_down_til > Time.now
    end

    def to_s
      @connection_string
    end
  end
end
