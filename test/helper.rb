require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start

require 'test/unit'
begin; require 'turn/autorun'; rescue LoadError; end
require 'shoulda-context'
require 'biopsy'

Turn.config.format = :pretty
Turn.config.trace = 2

Biopsy::Settings.instance.set_defaults

# Helper class provides methods for setting up test data.
class Helper

  require 'fileutils'

  attr_reader :tmp_dir
  attr_reader :target_dir
  attr_reader :domain_dir
  attr_reader :domain_path
  attr_reader :target_path
  attr_reader :objective_dir
  attr_reader :objective_path

  def cleanup
    self.instance_variables.each do |ivar|
      if ivar =~ /_dir/
        dir = self.instance_variable_get(ivar)
        FileUtils.rm_rf dir if File.exists? dir
      end
    end
  end

  # Create a tmp directory for test data
  def setup_tmp_dir
    @tmp_dir = File.expand_path('.tmp')
    Dir.mkdir @tmp_dir
  end

  # Return a hash of valid target data
  def target_data
    {
      :input_files => ['input.txt'],
      :output_files => ['output.txt'],
      :parameter_ranges => {
        :a => (3..300).step(3).to_a,
        :b => (2..50).step(2).to_a,
        :c => (1..100).to_a
      },
      :constructor_path => 'test_con.rb'
    }
  end

  # Setup the directory for target
  def setup_target
    @target_dir = File.join(@tmp_dir, 'targets')
    Dir.mkdir @target_dir
    Biopsy::Settings.instance.target_dir = [@target_dir]
  end

  # Create a valid target definition in the target dir
  def create_valid_target
    data = self.target_data
    name = 'test_target'
    @target_path = File.join(@target_dir, name + '.yml')
    self.yaml_dump data, @target_path
    name
  end

  # Return a hash of valid domain data
  def domain_data
    {
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
  end

  def setup_domain
    @domain_dir = File.join(@tmp_dir, 'domains')
    Dir.mkdir @domain_dir
    Biopsy::Settings.instance.domain_dir = [@domain_dir]
  end

  def create_valid_domain
    data = domain_data
    name = 'test_domain'
    @domain_path = File.join(@domain_dir, name + '.yml')
    self.yaml_dump data, @domain_path
    name
  end

  def setup_objective
    @objective_dir = File.join(@tmp_dir, 'objectives')
    Dir.mkdir @objective_dir
    Biopsy::Settings.instance.objectives_dir = [@objective_dir]
  end

  def create_valid_objective
    objective = %{
      class TestObjective < Biopsy::ObjectiveFunction
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
    @objective_path = File.join(@objective_dir, 'test_objective.rb')
    self.string_dump objective, @objective_path
  end

  # Dump +:object+ as YAML to +:file+
  def yaml_dump object, file
    self.string_dump object.to_yaml, file
  end

  # Dump +:string+ to +:file+
  def string_dump string, file
    File.open(file, 'w') do |f|
      f.puts string
    end
  end

end