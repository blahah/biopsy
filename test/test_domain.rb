require 'helper'

class TestDomain < Test::Unit::TestCase

  require 'fileutils'

  context "Domain" do

    setup do
      # create a valid Domain specification
      Dir.mkdir('.tmp')
      @fullpath = File.expand_path('.tmp')
      @settings = Biopsy::Settings.instance
      @settings.domain = 'test_domain'
      @settings.domain_dir = [@fullpath]
      @data = {
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
      @domainpath = File.join(@fullpath, 'test_domain.yml')
      File.open(@domainpath, 'w') do |f|
        f.puts @data.to_yaml
      end

      @domain = Biopsy::Domain.new
    end

    teardown do
      File.delete @domainpath if File.exists? @domainpath
      FileUtils.rm_rf '.tmp'  if File.exists? '.tmp'
    end

    should "be able to find the current domain" do
      assert_equal 'test_domain', @domain.get_current_domain
    end

    should "be able to find a definition" do
      assert_equal File.join(@fullpath, @settings.domain + '.yml'), @domain.locate_definition('test_domain')
    end

    should "fail to find a non-existent definition" do
      assert_equal nil, @domain.locate_definition('fake_filename')
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

        assert_raise Biopsy::DomainLoadError do
          @domain.load_by_name 'broken_thing'
        end

        File.delete filepath if File.exists? filepath
      end
    end
    
    should "write a template that can be loaded as a valid definition" do
      @domain.write_template File.join(@fullpath, 'template.yml')
      @domain.load_by_name 'template'
      assert_equal ['objective1', 'objective2'], @domain.objectives
    end

  end # Domain context

end # TestDomain