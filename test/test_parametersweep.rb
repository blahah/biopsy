require 'helper'

class TestParameterSweeper < Test::Unit::TestCase

  context "ParameterSweeper" do

    setup do
      ranges = {:a => [1,2,3], :b => [1,2,3]}
      @sweep = Biopsy::ParameterSweeper.new(ranges)
    end

    should "generate a list of combinations" do
      c = @sweep.combinations
      assert_equal c.size, 9
      assert_equal c, [{:a=>1, :b=>1}, {:a=>1, :b=>2}, {:a=>1, :b=>3},
       {:a=>2, :b=>1}, {:a=>2, :b=>2}, {:a=>2, :b=>3}, 
       {:a=>3, :b=>1}, {:a=>3, :b=>2}, {:a=>3, :b=>3}]
    end

  end # Experiment context

end # TestExperiment