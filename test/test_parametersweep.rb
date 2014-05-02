require 'helper'

class TestParameterSweeper < Test::Unit::TestCase

  context "ParameterSweeper" do

    setup do
      ranges = {:a => [1,2,3], :b => [1,2,3]}
      @sweep = Biopsy::ParameterSweeper.new(ranges)
      @sweep.setup
    end

    should "calculate number of combinations" do
      c = @sweep.combinations
      assert_equal c, 9
    end

    should 'generate list of combinations' do
      list=[]
      9.times do
        list << @sweep.next
      end
      assert_equal list, [{:a=>1, :b=>1}, {:a=>1, :b=>2}, {:a=>1, :b=>3},
       {:a=>2, :b=>1}, {:a=>2, :b=>2}, {:a=>2, :b=>3}, 
       {:a=>3, :b=>1}, {:a=>3, :b=>2}, {:a=>3, :b=>3}]
    end

    should "exit gracefully when you ask for too much" do
      c = 1
      10.times do
        c = @sweep.run_one_iteration(nil, 0)
      end
      assert_equal c, nil
    end

    should 'check if finished' do
      assert_equal @sweep.finished?, false, "at the start"
      8.times do
        @sweep.run_one_iteration(nil, 0)
      end
      assert_equal @sweep.finished?, false, "after 8"
      @sweep.run_one_iteration(nil, 0)
      assert_equal @sweep.finished?, false, "after 9"
      @sweep.run_one_iteration(nil, 0)
      assert_equal @sweep.finished?, true, "after 10"
    end

  end # Experiment context

end # TestExperiment