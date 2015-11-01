# Optimisation Framework: Settings
#
# == Description
#
# The Settings singleton object maintains general settings (as opposed to
# those specific to the experiment, which are contained in the Experiment
# object).
#
# Key settings include the location(s) of config file(s), the Domain that
# is currently active, and the directories to search for objective functions.
#
# Methods are provided for loading, listing, accessing and saving the settings
#
module Biopsy

  require 'singleton'
  require 'yaml'
  require 'pp'

  class SettingsError < StandardError
  end

  class Settings
    include Singleton

    attr_accessor :base_dir
    attr_accessor :target_dir
    attr_accessor :objectives_dir
    attr_accessor :objectives_subset
    attr_accessor :sweep_cutoff
    attr_accessor :keep_intermediates
    attr_accessor :gzip_intermediates
    attr_accessor :no_tempdirs

    def initialize
      self.set_defaults
    end

    def set_defaults
      # defaults
      @config_file = '~/.biopsyrc'
      @base_dir = ['.']
      @target_dir = ['targets']
      @objectives_dir = ['objectives']
      @objectives_subset = nil
      @sweep_cutoff = 100
      @keep_intermediates = false
      @gzip_intermediates = false
      @no_tempdirs = false
    end

    # Loads settings from a YAML config file. If no file is
    # specified, the default location ('~/.biopsyrc') is used.
    # Settings loaded from the file are merged into any
    # previously loaded settings.
    def load config_file
      config_file ||= @config_file
      newsets = YAML::load_file(config_file)
      raise 'Config file was not valid YAML' if newsets == false
      newsets.deep_symbolize.each_pair do |key, value|
        varname = "@#{key.to_s}".to_sym
        unless self.instance_variables.include? varname
          raise SettingsError.new "Key #{key.to_s} in settings file is not valid"
        end
        self.instance_variable_set(varname, value)
      end
    end

    # Saves the settings to a YAML config file. If no file is
    # specified, the default location ('~/.biopsyrc') is used.
    def save config_file
      config_file ||= @config_file
      File.open(config_file, 'w') do |f|
        f.puts self.to_s
      end
    end

    # Returns a hash of the settings
    def all_settings
      settings = {}
      instance_variables.each do |var|
        key = var[1..-1]
        settings[key] = self.instance_variable_get(var)
      end
      settings
    end

    # Returns a YAML string representation of the settings
    def to_s
      all_settings.to_yaml
    end

  end # Settings

end # Biopsy
