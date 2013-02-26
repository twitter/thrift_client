require File.expand_path('test_helper.rb', File.dirname(__FILE__))

class ThriftClientTest < Test::Unit::TestCase

  def setup
    @servers = ["127.0.0.1:1461", "127.0.0.1:1462", "127.0.0.1:1463"]
    @port = 1461
    @timeout = 0.2
    @options = {:protocol_extra_params => [false]}
    @pid = Process.fork do
      Signal.trap("INT") { exit }
      Greeter::Server.new("1463").serve
    end
    # Need to give the child process a moment to open the listening socket or
    # we get occasional "could not connect" errors in tests.
    sleep 0.05
  end

  def teardown
    Process.kill("INT", @pid)
    Process.wait
  end

  def test_inspect
    client = ThriftClient.new(Greeter::Client, @servers.last, @options)
    assert_equal "<ThriftClient(Greeter::Client) @current_server=127.0.0.1:1463>", client.inspect
  end

  def test_live_server
    assert_nothing_raised do
      ThriftClient.new(Greeter::Client, @servers.last, @options).greeting("someone")
    end
  end

  def test_dont_raise
    assert_nothing_raised do
      ThriftClient.new(Greeter::Client, @servers.first, @options.merge(:raise => false)).greeting("someone")
    end
  end

  def test_retries_correct_number_of_times
    stub_server(@port) do |socket|
      opts = @options.merge(:timeout => @timeout, :retries => 4, :server_retry_period => nil)
      client = ThriftClient.new(Greeter::Client, "127.0.0.1:#{@port}", opts)
      times_called = 0

      singleton_class = (class << client; self end)

      # disconnect_on_error! is called every time a server related
      # connection error happens. it will be called every try (so, retries + 1)
      singleton_class.send :define_method, :disconnect! do |*args|
        times_called += 1 if args[0]; super *args
      end

      assert_raises(Greeter::Client::TransportException) { client.greeting("someone") }
      assert_equal opts[:retries] + 1, times_called
    end
  end

  def test_dont_raise_with_defaults
    client = ThriftClient.new(Greeter::Client, @servers.first, @options.merge(:raise => false, :defaults => {:greeting => 1}))
    assert_equal 1, client.greeting
  end

  def test_defaults_dont_override_no_method_error
    client = ThriftClient.new(Greeter::Client, @servers, @options.merge(:raise => false, :defaults => {:Missing => 2}))
    assert_raises(NoMethodError) { client.Missing }
  end

  def test_random_fall_through
    assert_nothing_raised do
      10.times do
        client = ThriftClient.new(Greeter::Client, @servers, @options.merge(:retries => 2))
        client.greeting("someone")
        client.disconnect!
      end
    end
  end

  def test_lazy_connection
    assert_nothing_raised do
      ThriftClient.new(Greeter::Client, @servers[0,2])
    end
  end

  def test_post_conn_cb
    calledcnt = 0
    client = ThriftClient.new(Greeter::Client, @servers, @options.merge(:retries => 2))
    r = client.add_callback :post_connect do |cl|
      calledcnt += 1
      assert_equal(client, cl)
    end
    assert_equal(client, r)
    assert_nothing_raised do
      client.greeting("someone")
      client.disconnect!
    end
    assert_equal(1, calledcnt)
  end

  def test_before_method_cb
    before_method_counts = Hash.new { |hash, key| hash[key] = 0 }
    client = ThriftClient.new(Greeter::Client, @servers, @options.merge(:retries => 2))
    r = client.add_callback :before_method do |method_name|
      before_method_counts[method_name.to_sym] += 1
    end
    assert_equal(client, r)
    assert_nothing_raised do
      client.greeting("someone")
      client.yo("dude")
      client.yo("dawg")
      client.disconnect!
    end
    assert_equal({:greeting => 1, :yo => 2}, before_method_counts)
  end

  def test_on_exception_cb
    on_exception_counts = Hash.new { |h1, method_name| h1[method_name] = Hash.new { |h2, clazz| h2[clazz] = 0 }}
    client = ThriftClient.new(Greeter::Client, @servers[0,2], @options.merge(:retries => 2))
    r = client.add_callback :on_exception do |error, method_name|
      on_exception_counts[method_name.to_sym][error.class] += 1
    end
    assert_equal(client, r)
    assert_raises(ThriftClient::NoServersAvailable) do
      client.greeting("someone")
      client.disconnect!
    end
    assert_equal({:greeting => {ThriftClient::NoServersAvailable => 1}}, on_exception_counts)
  end

  def test_unknown_cb
    calledcnt = 0
    client = ThriftClient.new(Greeter::Client, @servers, @options.merge(:retries => 2))
    r = client.add_callback :unknown do |cl|
      assert(false)
    end
    assert_equal(nil, r)
  end

  def test_multiple_cb
    calledcnt = 0
    client = ThriftClient.new(Greeter::Client, @servers, @options.merge(:retries => 2))
    2.times do |i|
      r = client.add_callback :post_connect do |cl|
        calledcnt += 1
        assert_equal(client, cl)
      end
      assert_equal(client, r)
    end
    assert_nothing_raised do
      client.greeting("someone")
      client.disconnect!
    end
    assert_equal(2, calledcnt)
  end

  def test_no_servers_eventually_raise
    wascalled = false
    client = ThriftClient.new(Greeter::Client, @servers[0,2], @options.merge(:retries => 2))
    client.add_callback :post_connect do
      wascalled = true
    end
    assert_raises(ThriftClient::NoServersAvailable) do
      client.greeting("someone")
      client.disconnect!
    end
    assert(!wascalled)
  end

  def test_socket_timeout
    stub_server(@port) do |socket|
      measurement = Benchmark.measure do
        assert_raises(Greeter::Client::TransportException) do
          ThriftClient.new(Greeter::Client, "127.0.0.1:#{@port}",
            @options.merge(:timeout => 1, :connect_timeout => 0.5)
            ).greeting("someone")
        end
      end
      assert(measurement.real > 0.5 && measurement.real < 1.05)
    end
  end

  def test_framed_transport_timeout
    stub_server(@port) do |socket|
      measurement = Benchmark.measure do
        assert_raises(Greeter::Client::TransportException) do
          ThriftClient.new(Greeter::Client, "127.0.0.1:#{@port}",
            @options.merge(:timeout => @timeout, :connect_timeout => @timeout)
          ).greeting("someone")
        end
      end
      assert((measurement.real > @timeout), "#{measurement.real} < #{@timeout}")
    end
  end

  def test_buffered_transport_timeout
    stub_server(@port) do |socket|
      measurement = Benchmark.measure do
        client = ThriftClient.new(Greeter::Client, "127.0.0.1:#{@port}",
          @options.merge(:timeout => @timeout, :transport_wrapper => Thrift::BufferedTransport, :connect_timeout => @timeout)
        )
        assert_raises(Greeter::Client::TransportException) do
          client.greeting("someone")
        end
      end
      assert((measurement.real > @timeout), "#{measurement.real} < #{@timeout}")
    end
  end

  def test_buffered_transport_timeout_override
    # FIXME Large timeout values always are applied twice for some bizarre reason
    log_timeout = @timeout * 4
    stub_server(@port) do |socket|
      measurement = Benchmark.measure do
        client = ThriftClient.new(Greeter::Client, "127.0.0.1:#{@port}",
          @options.merge(:timeout => @timeout, :timeout_overrides => {:greeting => log_timeout}, :transport_wrapper => Thrift::BufferedTransport)
        )
        assert_raises(Greeter::Client::TransportException) do
          client.greeting("someone")
        end
      end
      assert((measurement.real > log_timeout), "#{measurement.real} < #{log_timeout}")
    end
  end

  def test_retry_period
    client = ThriftClient.new(Greeter::Client, @servers[0,2], @options.merge(:server_retry_period => 1, :retries => 2))
    assert_raises(ThriftClient::NoServersAvailable) { client.greeting("someone") }
    sleep 1.1
    assert_raises(ThriftClient::NoServersAvailable) { client.greeting("someone") }
  end

  def test_connect_retry_period
    client = ThriftClient.new(Greeter::Client, @servers[0], @options.merge(:server_retry_period => 0))
    assert_raises(ThriftClient::NoServersAvailable) { client.connect! }
  end

  def test_client_with_retry_period_drops_servers
    client = ThriftClient.new(Greeter::Client, @servers[0,2], @options.merge(:server_retry_period => 1, :retries => 2))
    assert_raises(ThriftClient::NoServersAvailable) { client.greeting("someone") }
    sleep 1.1
    assert_raises(ThriftClient::NoServersAvailable) { client.greeting("someone") }
  end

  def test_oneway_method
    client = ThriftClient.new(Greeter::Client, @servers, @options.merge(:server_max_requests => 2, :retries => 2))
    assert_nothing_raised do
      response = client.yo("dude")
    end
  end

  def test_server_max_requests_with_downed_servers
    client = ThriftClient.new(Greeter::Client, @servers, @options.merge(:server_max_requests => 2, :retries => 2))
    client.greeting("someone")
    last_client = client.last_client
    client.greeting("someone")
    assert_equal last_client, client.last_client

    # This next call maxes out the requests for that "client" object
    # and moves on to the next.
    client.greeting("someone")
    assert_not_equal last_client, new_client = client.last_client

    # And here we should still have the same client as the last one...
    client.greeting("someone")
    assert_equal new_client, client.last_client

    # Until we max it out, too.
    client.greeting("someone")
    assert_not_equal last_client, client.last_client
  end

  private

  def stub_server(port)
    socket = TCPServer.new('127.0.0.1', port)
    Thread.new { socket.accept }
    yield socket
  ensure
    socket.close
  end
end
