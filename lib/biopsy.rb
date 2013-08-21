require "biopsy/version"
require "biopsy/settings"
require "biopsy/domain"
require "biopsy/experiment"
require "biopsy/objective_handler"
require "biopsy/objective_function"
require "biopsy/opt_algorithm"
require "biopsy/optimisers/genetic_algorithm"
require "biopsy/optimisers/tabu_search"
require "biopsy/optimisers/parameter_sweeper"
require "biopsy/objectives/fastest_optimum"

module Biopsy

  class File

    # extend the File class to add File::which method.
    # returns the full path to the supplied cmd,
    # if it exists in any location in PATH
    def self.which(cmd)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each { |ext|
          exe = File.join(path, "#{cmd}#{ext}")
          return exe if File.executable? exe
        }
      end
      return nil
    end

  end # File

end # Biopsy

class Hash

  def deep_symbolize
    target = dup    
    target.inject({}) do |memo, (key, value)|
      value = value.deep_symbolize if value.is_a?(Hash)
      memo[(key.to_sym rescue key) || key] = value
      memo
    end
  end
  
  def deep_merge(other_hash)
    self.merge(other_hash) do |key, oldval, newval|
      oldval = oldval.to_hash if oldval.respond_to?(:to_hash)
      newval = newval.to_hash if newval.respond_to?(:to_hash)
      oldval.class.to_s == 'Hash' && newval.class.to_s == 'Hash' ? oldval.deep_merge(newval) : newval
    end
  end

end # Hash