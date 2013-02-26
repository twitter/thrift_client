class AbstractThriftClient
  include ThriftHelpers

  DISCONNECT_ERRORS = [
    IOError,
    Thrift::Exception,
    Thrift::ApplicationException,
    Thrift::TransportException
  ]

  DEFAULT_WRAPPED_ERRORS = [
    Thrift::ApplicationException,
    Thrift::TransportException,
  ]

  DEFAULTS = {
    :protocol => Thrift::BinaryProtocol,
    :protocol_extra_params => [],
    :transport => Thrift::Socket,
    :transport_wrapper => Thrift::FramedTransport,
    :raise => true,
    :defaults => {},
    :exception_classes => DISCONNECT_ERRORS,
    :exception_class_overrides => [],
    :retries => 0,
    :server_retry_period => 1,
    :server_max_requests => nil,
    :retry_overrides => {},
    :wrapped_exception_classes => DEFAULT_WRAPPED_ERRORS,
    :connect_timeout => 0.1,
    :timeout => 1,
    :timeout_overrides => {},
    :cached_connections => false
  }

  attr_reader :last_client, :client, :client_class, :current_server, :server_list, :options, :client_methods

  def initialize(client_class, servers, options = {})
    @options = DEFAULTS.merge(options)
    @options[:server_retry_period] ||= 0

    @client_class = client_class
    @server_list = Array(servers).collect do |s|
      Server.new(s, @client_class, @options)
    end.sort_by { rand }

    @current_server = @server_list.first

    @callbacks = {}
    @client_methods = []
    @client_class.instance_methods.each do |method_name|
      if method_name != 'send_message' && method_name =~ /^send_(.*)$/
        instance_eval("def #{$1}(*args); handled_proxy(:'#{$1}', *args); end", __FILE__, __LINE__)
        @client_methods << $1
      end
    end
    @request_count = 0
    @options[:wrapped_exception_classes].each do |exception_klass|
      name = exception_klass.to_s.split('::').last
      begin
        @client_class.const_get(name)
      rescue NameError
        @client_class.const_set(name, Class.new(exception_klass))
      end
    end
  end

  # Adds a callback that will be invoked at a certain time. The valid callback types are:
  #   :post_connect  - should accept a single AbstractThriftClient argument, which is the client object to
  #                    which the callback was added. Called after a connection to the remote thrift server
  #                    is established.
  #   :before_method - should accept a single method name argument. Called before a method is invoked on the
  #                    thrift server.
  #   :on_exception  - should accept 2 args: an Exception instance and a method name. Called right before the
  #                    exception is raised.
  def add_callback(callback_type, &block)
    case callback_type
    when :post_connect, :before_method, :on_exception
      @callbacks[callback_type] ||= []
      @callbacks[callback_type].push(block)
      # Allow chaining
      return self
    else
      return nil
    end
  end

  def inspect
    "<#{self.class}(#{client_class}) @current_server=#{@current_server}>"
  end

  # Force the client to connect to the server. Not necessary to be
  # called as the connection will be made on the first RPC method
  # call.
  def connect!(method = nil)
    start_time ||= Time.now
    @current_server = next_live_server
    @client = @current_server.client
    @last_client = @client
    do_callbacks(:post_connect, self)
  rescue IOError, Thrift::TransportException
    disconnect!(true)
    timeout = timeout(method)
    if timeout && Time.now - start_time > timeout
      no_servers_available!
    else
      retry
    end
  end

  def disconnect!(error = false)
    if @current_server
      @current_server.mark_down!(@options[:server_retry_period]) if error
      @current_server.close
    end

    @client = nil
    @current_server = nil
    @request_count = 0
  end

  private

  # Calls all callbacks of the specified type with the given args
  def do_callbacks(callback_type_sym, *args)
    return unless @callbacks[callback_type_sym]
    @callbacks[callback_type_sym].each do |callback|
      callback.call(*args)
    end
  end

  def next_live_server
    @server_index ||= 0
    @server_list.length.times do |i|
      cur = (1 + @server_index + i) % @server_list.length
      if @server_list[cur].up?
        @server_index = cur
        return @server_list[cur]
      end
    end
    no_servers_available!
  end

  def ensure_socket_alignment
    incomplete = true
    result = yield
    incomplete = false
    result
  # Thrift exceptions get read off the wire. We can consider them complete requests
  rescue Thrift::Exception => e
    incomplete = false
    raise e
  ensure
    disconnect! if incomplete
  end

  def handled_proxy(method_name, *args)
    begin
      connect!(method_name.to_sym) unless @client
      if has_timeouts?
        @client.timeout = timeout(method_name.to_sym)
      end
      @request_count += 1
      do_callbacks(:before_method, method_name)
      ensure_socket_alignment { @client.send(method_name, *args) }
    rescue *@options[:exception_class_overrides] => e
      raise_or_default(e, method_name)
    rescue *@options[:exception_classes] => e
      disconnect!(true)
      tries ||= (@options[:retry_overrides][method_name.to_sym] || @options[:retries]) + 1
      tries -= 1
      if tries > 0
        retry
      else
        raise_or_default(e, method_name)
      end
    rescue Exception => e
      raise_or_default(e, method_name)
    ensure
      disconnect! if @options[:server_max_requests] && @request_count >= @options[:server_max_requests]
    end
  end

  def raise_or_default(e, method_name)
    if @options[:raise]
      raise_wrapped_error(e, method_name)
    else
      @options[:defaults][method_name.to_sym]
    end
  end

  def raise_wrapped_error(e, method_name)
    do_callbacks(:on_exception, e, method_name)
    if @options[:wrapped_exception_classes].include?(e.class)
      raise @client_class.const_get(e.class.to_s.split('::').last), e.message, e.backtrace
    else
      raise e
    end
  end

  def has_timeouts?
    @has_timeouts ||= @options[:timeout_overrides].any? && transport_can_timeout?
  end

  def timeout(method = nil)
    @options[:timeout_overrides][method] || @options[:timeout]
  end

  def transport_can_timeout?
    if (@options[:transport_wrapper] || @options[:transport]).method_defined?(:timeout=)
      true
    else
      warn "ThriftClient: Timeout overrides have no effect with with transport type #{(@options[:transport_wrapper] || @options[:transport])}"
      false
    end
  end

  def no_servers_available!
    raise ThriftClient::NoServersAvailable, "No live servers in #{@server_list.inspect}."
  end
end
