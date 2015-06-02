require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start

require 'minitest/autorun'
begin; require 'turn/autorun'; rescue LoadError; end
require 'shoulda-context'
require 'biopsy'
require 'yaml'

Turn.config.format = :pretty
Turn.config.trace = 5

Biopsy::Settings.instance.set_defaults

# Helper class provides methods for setting up test data.
class Helper

  require 'fileutils'

  attr_reader :tmp_dir
  attr_reader :target_dir
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
      :name => 'target_test',
      :output => {
        :onlyfile => 'output.txt'
      },
      :parameters => {
        :a => {
          type: 'integer',
          opt: true,
          min: -40,
          max: 40,
          step: 5
        },
        :b => {
          type: 'integer',
          opt: true,
          min: 0,
          max: 40,
          step: 5
        },
        :c => {
          type: 'integer',
          opt: true,
          min: -20,
          max: 20
        }
      },
    }
  end

  # Setup the directory for target
  def setup_target
    @target_dir = File.join(@tmp_dir, 'targets')
    Dir.mkdir @target_dir
    Biopsy::Settings.instance.target_dir = [@target_dir]
  end

  # Create a valid target definition in the target dir
  def create_valid_target slow: false
    data = self.target_data
    data[:slow] = slow
    name = 'target_test'
    @target_path = File.join(@target_dir, name + '.yml')
    self.yaml_dump data, @target_path
    File.open(File.join(@target_dir, name + '.rb'), 'w') do |f|
      f.puts %Q{
class TargetTest

  def initialize
  end

  require 'yaml'

  def run(params)
    if (params[:slow])
      sleep 0.1
    end
    File.open('output.txt', 'w') do |f|
      f.puts(params.to_yaml)
    end
    nil
  end

  def fake_method
    :fake_method_success
  end

end
      }
    end
    name
  end

  def setup_objective
    @objective_dir = File.join(@tmp_dir, 'objectives')
    Dir.mkdir @objective_dir
    Biopsy::Settings.instance.objectives_dir = [@objective_dir]
  end

  def create_valid_objective
    objective = %Q{
class TestObjective < Biopsy::ObjectiveFunction

  require 'yaml'

  def initialize
    @optimum = 0
    @max = 0
    @weighting = 1
  end

  def run(raw_output, output_files, threads)
    file = output_files[:onlyfile].first
    input = YAML::load_file(file)
    a = input[:a].to_i
    b = input[:b].to_i
    c = input[:c].to_i

    value = - Math.sqrt((a-4)**2) - Math.sqrt((b-4)**2) - Math.sqrt((c-4)**2)
    {
      :optimum => @optimum,
      :max => @max,
      :weighting => @weighting,
      :result => value
    }
  end
end
    }
    @objective_path = File.join(@objective_dir, 'test_objective.rb')
    self.string_dump objective, @objective_path
  end

  def create_invalid_objective
    objective = %Q{
class TestObjective2 < Biopsy::ObjectiveFunction

  require 'yaml'

  def initialize
    @optimum = 0
    @max = 0
    @weighting = 1
  end

end
    }
    @objective_path = File.join(@objective_dir, 'test_objective2.rb')
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
