require File.expand_path('test_helper.rb', File.dirname(__FILE__))

class MinHeapTest < Test::Unit::TestCase
  def test_checkout_checkin
    h = ThriftHelpers::MinHeap.new(0, [1,2,3])
    [1,3,2].each do |expected|
      assert_equal expected, h.checkout
      h.add_sample(1)
      h.checkin
    end
  end

  def test_weight_range
    assert_raises(Errno::ERANGE) { ThriftHelpers::MinHeap.new(101, [1]) }
  end
end
