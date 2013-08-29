require 'helper'

class TestHash < Test::Unit::TestCase

  require 'pp'

  context "Hash" do

    setup do
      @a = {
        'a' => {
          'b' => 1,
          'c' => {
            'd' => [2, 3, 4]
          }
        }
      }
    end

    should "recursively symbolise keys" do
      b = {
        :a => {
          :b => 1,
          :c => {
            :d => [2, 3, 4]
          }
        }
      }
      assert @a != b, "hash with string keys not equal to hash with symbol keys"
      assert_equal @a.deep_symbolize, b, "symbolized string key hash equals symbol key hash"
    end

    should "recursively merge hashes" do
      b = {
        'a' => {
          'c' => {
            'e' => 'new value'
          }
        }
      }
      c = {
        'a' => {
          'b' => 1,
          'c' => {
            'd' => [2, 3, 4],
            'e' => 'new value'
          }
        }
      }
      assert_equal @a.deep_merge(b), c
    end

  end # Hash context

end # TestHash