require 'helper'

class TestFile < Test::Unit::TestCase

  context "File" do

    should "return full path to executable in $PATH" do
      filename = 'testfile'
      path = ENV['PATH'].split(File::PATH_SEPARATOR).first
      filepath = File.join(path, filename)
      File.open(filepath, 'w') do |f|
        f.puts 'test'
      end
      File.chmod(0777, filepath)
      assert_equal filepath, File.which(filename)
    end

  end # File context

end # TestFile