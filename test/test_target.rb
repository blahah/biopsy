require 'helper'

class TestTarget < Test::Unit::TestCase

  require 'fileutils'

  context "Target" do

    setup do
      # we need a valid config
      @data = {
        :input_files => ['left.fq', 'right.fq'],
        :output_files => ['assembly.fa'],
        :parameter_ranges => {
          :a => [1, 2, 3, 4],
          :b => [4, 6, 3, 2]
        },
        :constructor_path => 'test_con.rb'
      }
      @config_path = File.expand_path('test_target.yml')
      File.open(@config_path, 'w') do |f|
        f.puts @data.to_yaml
      end

      @settings = Biopsy::Settings.instance

      # a spare dir for test-specific config files
      Dir.mkdir('.tmp')
      @fullpath = File.expand_path('.tmp')
      @settings.target_dir = ['.', @fullpath]

      # we need a valid domain too
      @settings.domain = 'test_domain'
      @settings.domain_dir = [@fullpath]
      @domaindata = {
        :input_filetypes => [
          {
            :min => 1,
            :max => 2,
            :allowed_extensions => [
              'fastq',
              'fq',
              'fasta',
              'fa',
              'fas'
            ]
          }
        ],
        :output_filetypes => [
          {
            :n => 1,
            :allowed_extensions => [
              'fasta',
              'fa',
              'fas'
            ]
          }
        ],
        :objectives => [
          'test1', 'test2'
        ]
      }
      @domainpath = File.join(@fullpath, @settings.domain + '.yml')
      File.open(@domainpath, 'w') do |f|
        f.puts @domaindata.to_yaml
      end

      domain = Biopsy::Domain.new
      @target = Biopsy::Target.new domain
    end

    teardown do
      File.delete @config_path if File.exists? @config_path
      FileUtils.rm_rf '.tmp'  if File.exists? '.tmp'
    end

    should "be able to find an existing definition" do
      filepath = File.join(@fullpath, 'fake_thing.yml')
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
      @data.keys.each do |key|
        d = @data.clone
        d.delete key
        filepath = File.join(@fullpath, 'broken_thing.yml')
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
      config = YAML::load_file(@config_path).deep_symbolize
      @target.store_config config
      @data.each_pair do |key, value|
        assert_equal value, @target.instance_variable_get('@' + key.to_s)
      end
    end

    should "recognise a malformed or missing constructor" do
      config = YAML::load_file(@config_path).deep_symbolize
      @target.store_config config

      assert !@target.check_constructor, "missing constructor is invalid"

      File.open(@data[:constructor_path], 'w') do |f|
        f.puts '[x**2 for x in range(10)]' # python :)
      end
      assert !@target.check_constructor, "invalid ruby is invalid"
      File.delete @data[:constructor_path]
    end

  end # Target context

end # TestTarget context