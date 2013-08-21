require 'helper'

class TestSettings < Test::Unit::TestCase

  context "the Settings object" do

    setup do
      @data = {
        :domain => 'testdomain',
        :objective_dir => './objectives',
        :optimiser_dir => './optimisers'
      }
      @config_file = File.expand_path 'testconfig.yml'
      @settings = Biopsy::Settings.instance
      File.open(@config_file, 'w') do |f|
        f.puts @data.to_yaml
      end
      @settings.load @config_file
    end

    teardown do
      File.delete @config_file if File.exists? @config_file
    end

    should "load the specified config file" do
      assert @settings.domain == @data[:domain]
      assert @settings.objective_dir == @data[:objective_dir]
      assert @settings.optimiser_dir == @data[:optimiser_dir]
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
      assert_equal @data, @settings._settings
    end

    should "be a singleton" do
      assert_equal @settings.object_id, Biopsy::Settings.instance.object_id
    end

    should "make loaded settings available as methods" do
      assert @settings.domain == @data[:domain], 'domain key not loaded as method'
      assert @settings.objective_dir == @data[:objective_dir], 'objective_dir key not loaded as method'
      assert @settings.optimiser_dir == @data[:optimiser_dir], 'domain key not loaded as method'
    end

    should "give a purdy string representation" do
      assert_equal @settings.to_s, pp(@data)
    end

    should "produce a flattened list of settings" do
      assert_equal @settings.list_settings, @data.flatten
    end

  end # RunHandler context

end # TestRunHandler