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
      config[:shortname] = 'tt'
      @target.store_config config
      @h.target_data.each_pair do |key, value|
        if key == :parameters
          parsed = {}
          value.each_pair do |param, spec|
            if spec[:min] && spec[:max]
              r = (spec[:min]..spec[:max])
              r = spec[:step] ? r.step(spec[:step]) : r
              parsed[param] = r.to_a
            # elsif spec[:values]
            #   parsed[param] = spec[:values]
            # else
            #   assert false, "parameter #{param} with spec #{spec} has no range or values"
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

      assert_raise Biopsy::TargetLoadError do
        @target.check_constructor('target_missing')
      end

      File.open(@target.constructor_path, 'w') do |f|
        f.puts '[x**2 for x in range(10)]' # python :)
      end
      assert !@target.check_constructor('target_test'), "invalid ruby is invalid"
      File.delete @target.constructor_path
    end

    should "raise an exception if values doesn't provide an array" do
      params = {
        :a => {
          :type => 'integer',
          :opt => true,
          :values => 3
        }
      }
      assert_raise Biopsy::TargetLoadError do
        @target.generate_parameters params
      end
    end

    should "raise an exception for trying to load a string as an integer" do
      params = {
        :a => {
          :type => 'integer',
          :opt => true,
          :values => ["yes","no","maybe"]
        }
      }
      assert_raise Biopsy::TypeLoadError do
        @target.generate_parameters params
      end
    end

    should "raise an exception for trying to load an integer as a string" do
      params = {
        :b => {
          :type => 'string',
          :opt => true,
          :values => [1,2,3]
        }
      }
      assert_raise Biopsy::TypeLoadError do
        @target.generate_parameters params
      end
    end

    should "raise an exception of type TargetLoadError" do
      params = {
        :a => {
          :type => 'integer',
          :opt => true
        }
      }
      assert_raise Biopsy::TargetLoadError do
        @target.generate_parameters params
      end
    end

    should "load array" do
      params = {
        :a => {
          :type => 'string',
          :opt => true,
          :values => ["yes","no","maybe"]
        },
        :b => {
          :type => 'integer',
          :opt => false,
          :values => 0
        }
      }
      @target.generate_parameters params
      assert_equal @target.parameters, {:a => ["yes", "no", "maybe"]}
      assert_equal @target.options, {:b=>{:type=>"integer", :opt=>false, :values=>0}}
    end

    should "pass missing method calls to constructor iff \
            it directly defines them" do
      # this method is defined on the constructor in helper.rb
      assert_send([@target, :fake_method],
                  'valid method not passed to constructor')
      assert_equal @target.fake_method, :fake_method_success
      assert_raise NoMethodError do
        @target.totes_fake_method
      end
    end

  end # Target context

end # TestTarget context