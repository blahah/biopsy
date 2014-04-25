require 'helper'

class TestSettings < Test::Unit::TestCase

  context "Settings" do

    setup do
      @data = {
        :objectives_dir => './objectives'
      }
      @config_file = File.expand_path 'testconfig.yml'
      @settings = Biopsy::Settings.instance
      File.open(@config_file, 'w') do |f|
        f.puts @data.to_yaml
      end
      @settings.load @config_file
    end

    teardown do
      File.delete @config_file if File.exist? @config_file
    end

    should "load the specified config file" do
      assert @settings.objectives_dir == @data[:objectives_dir]
    end

    should "raise an error on loading invalid YAML file" do
      assert_raise(Biopsy::SettingsError) do
        @settings.load(File.expand_path('test/brokenconfig.yml'))
      end
    end

    should "complain about malformed config file" do
      # write non-YAML data to file
      File.open(@config_file, 'w') do |f|
        f.puts @test
      end
      assert_raise RuntimeError do
        @settings.load @config_file
      end
    end

    should "be able to save settings and load them identically" do
      @settings.save @config_file
      @settings.load @config_file
      @data.each_pair do |key, value|
        varname = "@#{key}".to_sym
        assert_equal value, @settings.instance_variable_get(varname)
      end
    end

    should "be a singleton" do
      assert_equal @settings.object_id, Biopsy::Settings.instance.object_id
    end

    should "make loaded settings available as methods" do
      assert @settings.objectives_dir == @data[:objectives_dir],
             'objectives_dir key not loaded as method'
    end

    should "produce a YAML string representation" do
      s = @settings.to_s
      h = YAML.load(s)
      h.each_pair do |key, value|
        varname = "@#{key}".to_sym
        assert_equal value, @settings.instance_variable_get(varname)
      end
    end

  end # RunHandler context

end # TestRunHandler
