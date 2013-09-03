require 'helper'

class TestTarget < Test::Unit::TestCase

  require 'fileutils'

  context "Target" do

    setup do
      @h = Helper.new
      @h.setup_tmp_dir

      # we need a domain
      @h.setup_domain
      domain_name = @h.create_valid_domain
      @domain = Biopsy::Domain.new domain_name

      # and a target
      @h.setup_target
      target_name = @h.create_valid_target
      @target = Biopsy::Target.new @domain
      @target.load_by_name target_name
    end

    teardown do
      @h.cleanup
    end

    should "be able to find an existing definition" do
      filepath = File.join(@h.target_dir, 'fake_thing.yml')
      File.open(filepath, 'w') do |f|
        f.puts "this doesn't matter"
      end

      assert_equal filepath, @target.locate_definition('fake_thing')
    end

    should "fail to find a non-existent definition" do
      assert_equal nil, @target.locate_definition('not_real')
    end

    should "reject any invalid config" do
      # generate all trivial invalid configs
      @h.target_data.keys.each do |key|
        d = @h.target_data.clone
        d.delete key
        filepath = File.join(@h.target_dir, 'broken_thing.yml')
        File.open(filepath, 'w') do |f|
          f.puts d.to_yaml
        end

        assert_raise Biopsy::TargetLoadError do
          @target.load_by_name 'broken_thing'
        end

        File.delete filepath if File.exists? filepath
      end
    end

    should "reject a config that doesn't match the domain spec" do
      d = @h.target_data
      d[:input_files][:fake] = 'another.file'
      assert @target.validate_config(d).length > 0
    end

    should "be able to store a loaded config file" do
      config = YAML::load_file(@h.target_path).deep_symbolize
      @target.store_config config
      @h.target_data.each_pair do |key, value|
        assert_equal value, @target.instance_variable_get('@' + key.to_s)
      end
    end

    should "recognise a malformed or missing constructor" do
      config = YAML::load_file(@h.target_path).deep_symbolize
      @target.store_config config

      assert !@target.check_constructor, "missing constructor is invalid"

      File.open(@h.target_data[:constructor_path], 'w') do |f|
        f.puts '[x**2 for x in range(10)]' # python :)
      end
      assert !@target.check_constructor, "invalid ruby is invalid"
      File.delete @h.target_data[:constructor_path]
    end

  end # Target context

end # TestTarget context