require 'helper'

class TestExperiment < Test::Unit::TestCase

  context "Experiment" do

    setup do
      @dom = Biopsy::Domain.new
      @exp = Biopsy::Experiment.new @dom
    end

    # should "fail to init when passed a bad constructor" do
    #   assert false
    # end

    # should "fail to init when passed invalid settings" do
    #   assert false
    # end

    # should "only accept a positive integer number of threads" do
    #   assert false
    # end

    # should "automatically select an optimiser if none is specified" do
    #   assert false
    # end

    # should "return an optimal set of parameters and score when run" do
    #   assert false
    # end

    # should "update current parameters after each iteration run" do
    #   assert false
    # end

    # should "be able to select an initial set of parameters" do
    #   assert false
    # end

  end # Experiment context

end # TestExperiment