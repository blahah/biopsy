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
Turn.config.trace = 10

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
      :input_files => {
        :in => 'input.txt'
      },
      :output_files => {
        :params => 'output.txt'
      },
      :parameter_ranges => {
        :a => (-40..40).step(2).to_a,
        :b => (0..100).step(2).to_a,
        :c => (-50..50).to_a
      },
      :constructor_path => 'test_constructor.rb'
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
    File.open(File.join(@target_dir, data[:constructor_path]), 'w') do |f|
      f.puts %Q{
class TestConstructor

  require 'yaml'

  def run(params)
    File.open('output.txt', 'w') do |f|
      f.puts(params.to_yaml)
    end
    { :params => File.expand_path('output.txt') }
  end

end
      }
    end
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
    objective = %Q{
class TestObjective < Biopsy::ObjectiveFunction

  require 'yaml'

  def initialize
    @optimum = 0
    @max = 0
    @weighting = 1
  end

  def run(input, threads)
    file = input[:params]
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