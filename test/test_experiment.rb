require 'helper'

class TestExperiment < Test::Unit::TestCase

  context "Experiment" do

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
    end

    teardown do
      Dir.chdir(@tmpdir) do
        Dir['*'].each do |f|
          File.delete f
        end
      end
      FileUtils.rm_rf @tmpdir  if File.exists? @tmpdir
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
        assert @target_data[:parameter_ranges][param].include? value
      end
    end

    should "be able to select a starting point" do
      e = Biopsy::Experiment.new('test_target', 'test_domain')
      start_point = e.start
      start_point.each_pair do |param, value|
        assert @target_data[:parameter_ranges][param].include? value
      end
    end

    should "respect user's choice of starting point" do
      s = {:a => 2, :b => 4}
      e = Biopsy::Experiment.new('test_target', 'test_domain', s)
      assert_equal s, e.start
    end

    should "automatically select an optimiser if none is specified" do
      assert false
    end

    should "return an optimal set of parameters and score when run" do
      assert false
    end

    should "update current parameters after each iteration run" do
      assert false
    end

  end # Experiment context

end # TestExperiment