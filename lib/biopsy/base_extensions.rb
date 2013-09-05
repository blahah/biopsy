class String

  # return a CamelCase version of self
  def camelize
    return self if self !~ /_/ && self =~ /[A-Z]+.*/
    split('_').map{|e| e.capitalize}.join
  end

end # String

class File

  # return the full path to the supplied cmd executable,
  # if it exists in any location in PATH
  def self.which(cmd)
    exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
    ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
      exts.each do |ext|
        exe = File.join(path, "#{cmd}#{ext}")
        return exe if File.executable? exe
      end
    end
    return nil
  end

end # File

class Hash

  # recursively convert all keys to symbols
  def deep_symbolize
    target = dup    
    target.inject({}) do |memo, (key, value)|
      value = value.deep_symbolize if value.is_a?(Hash)
      memo[(key.to_sym rescue key) || key] = value
      memo
    end
  end
  
  # recursively merge two hashes
  def deep_merge(other_hash)
    self.merge(other_hash) do |key, oldval, newval|
      oldval = oldval.to_hash if oldval.respond_to?(:to_hash)
      newval = newval.to_hash if newval.respond_to?(:to_hash)
      oldval.class.to_s == 'Hash' && newval.class.to_s == 'Hash' ? oldval.deep_merge(newval) : newval
    end
  end

end # Hash

class Array

  # return the arithmetic mean of the elements in the array.
  # Requires the array to contain only objects of class Fixnum.
  # If any other class is encountered, an error will be raised.
  def mean
    self.inject(0.0) { |sum, element| sum + element } / self.size
  end

end # Array