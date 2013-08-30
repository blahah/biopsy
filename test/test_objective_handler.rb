require 'helper'

class TestObjectiveHandler < Test::Unit::TestCase

  context "ObjectiveHandler" do

    setup do
      @target_data = {
        :input_files => ['input.txt'],
        :output_files => ['output.txt'],
        :parameter_ranges => {
          :a => [1, 2, 3, 4],
          :b => [4, 6, 3, 2]
        },
        :constructor_path => 'test_con.rb'
      }
      @domain_data = {
        :input_filetypes => [
          {
            :n => 1,
            :allowed_extensions => [
              '.txt'
            ]
          }
        ],
        :output_filetypes => [
          {
            :n => 1,
            :allowed_extensions => [
              '.txt'
            ]
          }
        ],
        :objectives => [
          'test1', 'test2'
        ]
      }
      tmpdir = '.tmp'
      @tmpdir = File.expand_path(tmpdir)
      Dir.mkdir(@tmpdir)
      Biopsy::Settings.instance.target_dir = [@tmpdir]
      Biopsy::Settings.instance.domain_dir = [@tmpdir]
      File.open(File.join(@tmpdir, 'test_target.yml'), 'w') do |f|
        f.puts @target_data.to_yaml
      end
      File.open(File.join(@tmpdir, 'test_domain.yml'), 'w') do |f|
        f.puts @domain_data.to_yaml
      end
      @domain = Biopsy::Domain.new()
      @target = Biopsy::Target.new
      @target.load
    end

    should "fail to init when no domain is provided" do
      assert false
    end

    should "fail to init when no target is provided" do

    end

    should "return loaded objectives on init" do
      assert false
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