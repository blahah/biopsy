

module Biopsy

  class TargetLoadError < Exception
  end

  class TypeLoadError < Exception
  end

  class Target
    require 'yaml'
    require 'set'

    attr_accessor :parameters
    attr_accessor :options
    attr_accessor :output
    attr_accessor :name
    attr_accessor :shortname
    attr_reader :constructor_path

    # load target with +name+.
    def load_by_name name
      path = self.locate_definition name
      raise TargetLoadError.new("Target definition file does not exist for #{name}") if path.nil?
      config = YAML::load_file(path)
      raise TargetLoadError.new("Target definition file #{path} is not valid YAML") if config.nil?
      config = config.deep_symbolize
      self.store_config config
      self.check_constructor name
      self.load_constructor
    end

    # given the name of a target, return the path
    # to the definition YAML file. All +:target_dir+s defined in Settings are
    # searched and the first matching YAML file is loaded. 
    def locate_definition name
      self.locate_file(name + '.yml')
    end

    # store the values in +:config+, checking they are valid
    def store_config config
      required = Set.new([:name, :parameters, :output])
      missing = required - config.keys
      raise TargetLoadError.new("Required keys are missing from target definition: #{missing.to_a.join(",")}") unless missing.empty?
      config.each_pair do |param, data|
        case param
        when :name
          raise TargetLoadError.new('Target name must be a string') unless data.is_a? String
          @name = data
        when :shortname
          raise TargetLoadError.new('Target shortname must be a string') unless data.is_a? String
          @shortname = data
        when :parameters
          self.generate_parameters data
        when :output
          raise TargetLoadError.new('Target output must be a hash') unless data.is_a?(Hash)
          @output = data
        end
      end
    end

    # Locate a file with name in one of the target_dirs
    def locate_file name
      Settings.instance.target_dir.each do |dir|
        Dir.chdir File.expand_path(dir) do
          return File.expand_path(name) if File.exists? name
        end
      end
      raise TargetLoadError.new("Couldn't find file #{name}")
      nil
    end

    # Validate the constructor. True if valid, false otherwise.
    def check_constructor name
      @constructor_path = self.locate_file name + '.rb'
      raise TargetLoadError.new("constructor path is not defined for this target") if @constructor_path.nil?
      self.valid_ruby? @constructor_path
    end

    # Load constructor
    def load_constructor
      require @constructor_path 
      file_name = File.basename(@constructor_path, '.rb')
      constructor_name = file_name.camelize
      @constructor = Module.const_get(constructor_name).new
    end

    # Run the constructor for the parameter set +:params+
    def run params
      @constructor.run params
    end

    # true if file is valid ruby
    def valid_ruby? file
      return false unless ::File.exists? file
      result = `ruby -c #{file} > /dev/null 2>&1`
      !result.size.zero?
    end

    # convert parameter specification to a hash of arrays and ranges
    def generate_parameters params
      @parameters = {}
      @options = {}
      params.each_pair do |param, data|
        if data[:opt]
          # optimise this parameter
          if data[:values] 
            # definition has provided an array of values
            if !data[:values].is_a? Array
              raise TargetLoadError.new("'values' for parameter #{param} is not an array")
            end
            if data[:type] == 'integer'
              data[:values].each do |v|
                raise TypeLoadError.new("'values' for parameter #{param} expected integer") unless v.is_a? Integer
              end
            elsif data[:type] == 'string'
              data[:values].each do |v|
                raise TypeLoadError.new("'values' for parameter #{param} expected string") unless v.is_a? String
              end
            end
            @parameters[param] = data[:values]
          else
            # definition has specified a range
            min, max, step = data[:min], data[:max], data[:step]
            unless min && max
              raise TargetLoadError.new("min and max must be set for parameter #{param}") 
            end
            range = (min..max)
            range = range.step(step) if step
            @parameters[param] = range.to_a
          end
        else
          # present option to user
          @options[param] = data
        end
      end
    end

    # return the total number of possible permutations of
    def count_parameter_permutations
      @parameters.each_pair.map{ |k, v| v }.reduce(1) { |n, arr| n * arr.size }
    end

    # pass calls to missing methods to the constructor iff
    # the constructor's class directly defines that method
    def method_missing(method, *args, &block)
      const_methods = @constructor.class.instance_methods(false)
      if const_methods.include? method
        return @constructor.send(method, *args, &block)
      else
        super
      end
    end

    # accurately report ability to respond to methods passed
    # to constructor
    def respond_to?(method, *args, &block)
      const_methods = @constructor.class.instance_methods(false)
      if const_methods.include? method
        true
      else
        super
      end
    end

  end # end of class Target

end # end of module Biopsy