require 'helper'

class TestExperiment < Test::Unit::TestCase

  context "Experiment" do

    setup do
      @h = Helper.new
      @h.setup_tmp_dir

      # we need a domain
      @h.setup_domain
      domain_name = @h.create_valid_domain
      @domain = Biopsy::Domain.new domain_name

      # and a target
      @h.setup_target
      target_name = @h.create_valid_target
      @target = Biopsy::Target.new @domain
      @target.load_by_name target_name

      # and an objective
      @h.setup_objective
      objective_name = @h.create_valid_objective
    end

    teardown do
      @h.cleanup
    end

    should "fail to init when passed a non existent target" do
      assert_raise Biopsy::TargetLoadError do
        Biopsy::Experiment.new('fake_target', 'test_domain')
      end
    end

    should "fail to init when passed a non existent domain" do
      assert_raise Biopsy::DomainLoadError do
        Biopsy::Experiment.new('test_target', 'fake_domain')
      end
    end

    should "be able to select a valid point from the parameter space" do
      e = Biopsy::Experiment.new('test_target', 'test_domain')
      start_point = e.random_start_point
      start_point.each_pair do |param, value|
        assert @h.target_data[:parameter_ranges][param].include? value
      end
    end

    should "be able to select a starting point" do
      e = Biopsy::Experiment.new('test_target', 'test_domain')
      start_point = e.start
      start_point.each_pair do |param, value|
        assert @h.target_data[:parameter_ranges][param].include? value
      end
    end

    should "respect user's choice of starting point" do
      s = {:a => 2, :b => 4}
      e = Biopsy::Experiment.new('test_target', 'test_domain', s)
      assert_equal s, e.start
    end

    should "automatically select an optimiser if none is specified" do
      e = Biopsy::Experiment.new('test_target', 'test_domain')
      assert e.algorithm.kind_of? Biopsy::TabuSearch
    end

    should "return an optimal set of parameters and score when run" do
      e = Biopsy::Experiment.new('test_target', 'test_domain')
      known_best = {
        :a => 4,
        :b => 4,
        :c => 4
      }
      best_found = e.run[:parameters]
      assert_equal known_best, best_found
    end

  end # Experiment context

end # TestExperiment