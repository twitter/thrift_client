require 'thrift_client/connection'

module ThriftHelpers
  class Server
    class ServerMarkedDown < StandardError; end

    def initialize(connection_string, client_class, options = {})
      @connection_string = connection_string
      @client_class = client_class
      @options = options

      @cached = @options.has_key?(:cached_connections) ? @options[:cached_connections] : true

      @marked_down_til = nil
    end

    def mark_down!(til)
      close(true)
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

    def connection
      @connection ||= Connection::Factory.create(
        @options[:transport], @options[:transport_wrapper],
        @connection_string, @options[:connect_timeout])
    end

    def connect!
      return if open?

      self.timeout = @options[:connect_timeout]
      connection.connect!
      self.timeout = @options[:timeout]
    end

    def client
      @client ||= begin
        connect!

        @client_class.new(
          @options[:protocol].new(self, *@options[:protocol_extra_params]))
      end
    end

    def open?
      connection.open?
    end

    def close(teardown = false)
      if teardown || !@cached
        connection.close if open?
        @client = nil
      end
    end

    def transport
      connection.transport
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
        transport.timeout = timeout if transport.respond_to?(:timeout=)
      end

      def timeout
        transport.timeout
      end
    end
    include TransportInterface
  end
end
