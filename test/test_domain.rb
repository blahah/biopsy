require 'helper'

class TestDomain < Test::Unit::TestCase

  require 'fileutils'

  context "Domain" do

    setup do
      @h = Helper.new
      @h.setup_tmp_dir

      # we need a domain
      @h.setup_domain
      domain_name = @h.create_valid_domain
      @domain = Biopsy::Domain.new domain_name
    end

    teardown do
      @h.cleanup
    end

    should "be able to find the current domain" do
      assert_equal 'test_domain', @domain.get_current_domain
    end

    should "be able to find a definition" do
      assert_equal @h.domain_path, @domain.locate_definition('test_domain')
    end

    should "fail to find a non-existent definition" do
      assert_equal nil, @domain.locate_definition('fake_filename')
    end

    should "reject any invalid config" do
      # generate all trivial invalid configs
      @h.domain_data.keys.each do |key|
        d = @h.domain_data.clone
        d.delete key
        filepath = File.join(@h.domain_dir, 'broken_thing.yml')
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
      @domain.write_template File.join(@h.domain_dir, 'template.yml')
      @domain.load_by_name 'template'
      assert_equal ['objective1', 'objective2'], @domain.objectives
    end

  end # Domain context

end # TestDomain