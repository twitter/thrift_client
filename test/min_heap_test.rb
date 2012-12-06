require File.expand_path('test_helper.rb', File.dirname(__FILE__))

class MinHeapTest < Test::Unit::TestCase
  def test_checkout_checkin
    h = ThriftHelpers::MinHeap.new(50, ('a'..'z').to_a)
    100000.times do
      #print h.checkout
      h.add_sample(rand(1000))
      h.checkin
    end
    #puts
    #p h.current_state
  end
end
