# encoding: utf-8

module Biopsy
  module VERSION
    MAJOR = 0
    MINOR = 1
    PATCH = 0
    BUILD = 'alpha'

    STRING = [MAJOR, MINOR, PATCH].compact.join('.')
    STRING += "-#{BUILD}" if BUILD
  end
end # Biopsy