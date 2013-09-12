require 'helper'

class TestTarget < Test::Unit::TestCase

  require 'fileutils'

  context "Target" do

    setup do
      @h = Helper.new
      @h.setup_tmp_dir

      # and a target
      @h.setup_target
      target_name = @h.create_valid_target
      @target = Biopsy::Target.new
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
      assert_raise Biopsy::TargetLoadError do
        @target.locate_definition('not_real')
      end
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

    should "be able to store a loaded config file" do
      config = YAML::load_file(@h.target_path).deep_symbolize
      @target.store_config config
      @h.target_data.each_pair do |key, value|
        if key == :parameters
          parsed = {}
          value.each_pair do |param, spec|
            if spec[:min] && spec[:max]
              r = (spec[:min]..spec[:max])
              r = spec[:step] ? r.step(spec[:step]) : r
              parsed[param] = r.to_a
            elsif spec[:values]
              parsed[param] = spec[:values]
            else
              assert false, "parameter #{param} with spec #{spec} has no range or values"
            end
          end
          parsed.each_pair do |param, spec|
            assert_equal spec, @target.parameters[param]
          end
        else
          assert_equal value, @target.instance_variable_get('@' + key.to_s)
        end
      end
    end

    should "recognise a malformed or missing constructor" do
      config = YAML::load_file(@h.target_path).deep_symbolize
      @target.store_config config

      assert !@target.check_constructor, "missing constructor is invalid"

      File.open(@target.constructor_path, 'w') do |f|
        f.puts '[x**2 for x in range(10)]' # python :)
      end
      assert !@target.check_constructor, "invalid ruby is invalid"
      File.delete @target.constructor_path
    end

  end # Target context

end # TestTarget context