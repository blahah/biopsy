
module Biopsy

  class Domain

    attr_reader :name
    attr_reader :input_filetypes
    attr_reader :output_filetypes
    attr_reader :objectives

    require 'yaml'

    def initialize domain=nil
      @name = self.get_current_domain if domain.nil?
      self.load_by_name @name
    end

    # Return the name of the currently active domain.
    def get_current_domain
      Settings.instance.domain
    rescue
      raise "You must specify the domain to use in the biopsy settings file or at the command line."
    end

    # Return the path to the YAML definition file for domain with +:name+.
    # All +:domain_dirs+ in Settings are searched and the first matching
    # file is returned.
    def locate_definition name
      Settings.instance.locate_config :domain_dir, name
    end

    # Check and apply the settings in +:config+ (Hash).
    def apply_config config
      [:input_filetypes, :output_filetypes, :objectives].each do |key|
        raise "Domain definition is missing the required key #{key}" unless config.has_key? key 
        self.instance_variable_set('@' + key.to_s, config[key])
      end
    end

    # Load and apply the domain definition with +:name+
    def load_by_name name
      path = self.locate_definition(name)
      config = YAML::load_file(path).deep_symbolize
      self.apply_config config
    end

    # Validate a Target, returning true if the target meets
    # the specification of this Domain, and false otherwise.
    # +:target+, the Target object to validate.
    def target_valid? target
      valid = true
      target[:input_filetypes].each { |f| valid = false unless self.input_files.include? f }
      target[:output_filetypes].each { |f| valid = false unless self.output_files.include? f }
      valid
    end

    # Write out a template Domain definition to +:filename+
    def write_template filename
      data = {
        :input_filetypes => [
          {
            :min => 1,
            :max => 2,
            :allowed_extensions => [
              'txt',
              'csv',
              'tsv'
            ]
          },
          {
            :n => 2,
            :allowed_extensions => [
              'png'
            ]
          }
        ],
        :output_filetypes => [
          {
            :n => 1,
            :allowed_extensions => [
              'pdf',
              'xls'
            ]
          }
        ],
        :objectives => [
          'objective1', 'objective2'
        ]
      }
      File.open(filename, 'w') do |f|
        f.puts data.to_yaml
      end
    end

  end # end of class Domain

end # end of module Biopsy