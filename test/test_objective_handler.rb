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
      oh = Biopsy::ObjectiveHandler.new @domain, @target
      refute oh.objectives.empty?
    end

    should "prefer local objective list to full set" do
      Dir.chdir(@h.objective_dir) do
        objective = %{
          class AnotherObjective < Biopsy::ObjectiveFunction
            def run(input)
              a = input[:a]
              b = input[:b]
              c = input[:c]
              # should be easy - convex function taken from http://www.economics.utoronto.ca/osborne/MathTutorial/CVNF.HTM
              #  f (x1, x2, x3) = x12 + 2x22 + 3x32 + 2x1x2 + 2x1x3
              # optimum is a=100, b=100, c=50, score=57800
              a**2 + 2 * (b**2) + 3 * (c**2) + 2 * (a * b) + 2 * (a + c)
            end
          end
        }
        File.open('another_objective.rb', 'w') do |f|
          f.puts objective
        end
        File.open('objectives.txt', 'w') do |f|
          f.puts 'another_objective'
        end
      end
      oh = Biopsy::ObjectiveHandler.new @domain, @target
      assert_equal 1, oh.objectives.length
      assert_equal 'AnotherObjective', oh.objectives.keys.first
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