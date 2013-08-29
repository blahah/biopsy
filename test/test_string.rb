require 'helper'

class TestString < Test::Unit::TestCase

  context "String" do

    should "return CamelCase version of snake_case" do
      assert_equal "snake_case".camelize, "SnakeCase"
      assert_equal "a_b_c_d".camelize, "ABCD"
    end

  end # String context

end # TestString