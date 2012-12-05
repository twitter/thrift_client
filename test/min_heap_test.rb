require File.expand_path('test_helper.rb', File.dirname(__FILE__))

class MinHeapTest < Test::Unit::TestCase
  def test_checkout_checkin
    h = MinHeap.new(100, [1,2,3,4,5])
    100.times do
      h.checkout
      h.add_sample(rand(100))
      h.checkin
    end
  end
end
