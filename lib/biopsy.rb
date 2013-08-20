require "biopsy/version"

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

end
