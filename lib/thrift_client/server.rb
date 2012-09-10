require 'thrift_client/connection'

module ThriftHelpers
  class Server
    attr_reader :marked_down_at

    class ServerMarkedDown < StandardError; end

    def initialize(connection_string)
      @connection_string = connection_string
      @connection = nil
      @marked_down_at = nil
    end

    def open(trans, wrap, timeout)
      if down?
        raise ServerMarkedDown, "marked down at #{@marked_down_at}"
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

    def mark_down!
      @marked_down_at = Time.now
    end

    def down?
      @marked_down_at && @marked_down_at > Time.now
    end

    def to_s
      @connection_string
    end
  end
end
