require 'thrift_client/connection'

module ThriftHelpers
  class Server
    class ServerMarkedDown < StandardError; end

    def initialize(connection_string)
      @connection_string = connection_string
      @connection = nil
      @marked_down_til = nil
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

    def open(trans, wrap, conn_timeout, trans_timeout)
      if down?
        raise ServerMarkedDown, "marked down until #{@marked_down_til}"
      end

      @connection = Connection::Factory.create(trans, wrap, @connection_string, conn_timeout)
      @connection.connect!

      if wrap || trans.respond_to?(:timeout=)
        timeout = trans_timeout
      end

      self
    end

    def open?
      @connection.open?
    end

    def close
      @connection.close rescue nil #TODO
      @connection = nil
    end

    def transport
      @connection.transport
    end

    module TransportInterface
      def read(sz)
        transport.read(sz)
      end

      def read_byte
        transport.read_byte
      end

      def read_into_buffer(buffer, size)
        transport.read_into_buffer(buffer, size)
      end

      def read_all(sz)
        transport.read_all(sz)
      end

      def write(buf)
        transport.write(buf)
      end
      alias_method :<<, :write

      def flush
        transport.flush
      end

      def timeout=(timeout)
        transport.timeout = timeout
      end

      def timeout
        transport.timeout
      end
    end
    include TransportInterface
  end
end
