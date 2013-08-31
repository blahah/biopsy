require 'helper'

class TestObjectiveHandler < Test::Unit::TestCase

  context "ObjectiveHandler" do

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

    should "return loaded objectives on init" do
      pp Biopsy::ObjectiveHandler.new @domain, @target
    end

    should "prefer local objective list to full set" do
      assert false
    end

    should "run an objective and return the result" do
      assert false
    end

    should "perform euclidean distance dimension reduction" do
      assert false
    end

    should "update current parameters after each iteration run" do
      assert false
    end

    should "run all objectives for an output, returning results" do
      assert false
    end

  end # Experiment context

end # TestExperiment