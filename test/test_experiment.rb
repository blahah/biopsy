require 'helper'

class TestExperiment < Test::Unit::TestCase

  context "Experiment" do

    setup do
      # create a target called 'target_test'
      @h = Helper.new
      @h.setup_tmp_dir

      # and a target
      @h.setup_target
      target_name = @h.create_valid_target
      @target = Biopsy::Target.new
      @target.load_by_name target_name

      # and an objective
      @h.setup_objective
      @h.create_valid_objective
    end

    teardown do
      @h.cleanup
    end

    should "fail to init when passed a non existent target" do
      assert_raise Biopsy::TargetLoadError do
        Biopsy::Experiment.new('fake_target')
      end
    end

    should "be able to select a valid point from the parameter space" do
      e = Biopsy::Experiment.new('target_test')
      start_point = e.random_start_point
      start_point.each_pair do |param, value|
        assert @target.parameters[param].include?(value), "#{value} not in #{@target.parameters[param]}"
      end
    end

    should "be able to select a starting point" do
      e = Biopsy::Experiment.new('target_test')
      start_point = e.start
      start_point.each_pair do |param, value|
        assert @target.parameters[param].include?(value), "#{value} not in #{@target.parameters[param]}"
      end
    end

    should "respect user's choice of starting point" do
      s = {:a => 4, :b => 2} 
      e = Biopsy::Experiment.new('target_test', start: s)
      assert_equal s, e.start
    end

    should "automatically select an optimiser if none is specified" do
      e = Biopsy::Experiment.new('target_test')
      assert e.algorithm.kind_of? Biopsy::TabuSearch
    end

    should "return an optimal set of parameters and score when run" do
      Dir.chdir @h.tmp_dir do
        e = Biopsy::Experiment.new('target_test')
        known_best = -4
        best_found = e.run[:score]
        assert known_best < best_found
      end
    end

    should "run really quickly when starting from the optimal parameters" do
      Dir.chdir @h.tmp_dir do
        s = {:a => 4, :b => 4, :c => 4} 
        e = Biopsy::Experiment.new('target_test', start: s)
        known_best = -4
        best_found = e.run[:score]
        assert known_best < best_found
      end
    end

    should "run using the parameter sweeper (with limit)" do
      Dir.chdir @h.tmp_dir do
        p = Biopsy::ParameterSweeper.new(@target.parameters, limit: 250)
        e = Biopsy::Experiment.new('target_test', algorithm: p)
        best_found = e.run[:score]
        assert best_found != nil
      end
    end
  end # Experiment context

end # TestExperiment