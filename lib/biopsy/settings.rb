# Optimisation Framework: Settings
#
# == Description
#
# The Settings singleton object maintains general settings (as opposed to)
# those specific to the experiment, which are contained in the Experiment
# object.
#
# Key settings include the location(s) of config file(s), the Domain that
# is currently active, the directories to search for objective functions
#
# Methods are provided for loading, listing, accessing and saving the settings
#
module Biopsy

  require 'singleton'
  require 'YAML'
  require 'pp'

  class Settings
    include Singleton

    attr_reader :_settings

    def initialize
      self.clear
      @config_file = '~/.biopsyrc'
    end

    def load(config_file=@config_file)
      newsets = YAML::load_file(config_file)
      raise 'Config file was not valid YAML' if newsets == false
      @_settings = @_settings.deep_merge newsets.deep_symbolize
    end

    def save(config_file=@config_file)
      ::File.open(config_file, 'w') do |f|
        f.puts @_settings.to_yaml
      end
    end

    def method_missing(name, *args, &block)
      if args.empty?
        # access the value
        @_settings[name.to_sym] || super
      elsif name.to_s[-1] == '='
        # assign the value
        @_settings[name.to_s[0..-2].to_sym] = args[0]
      end
    end

    def respond_to_missing?(name, include_private = false)
      @_settings.has_key? name.to_sym || super
    end

    def list_settings
      @_settings.flatten
    end

    def to_s
      pp @_settings
    end

    def clear
      @_settings = {}
    end
  end # end of class Settings

end # end of module Biopsy