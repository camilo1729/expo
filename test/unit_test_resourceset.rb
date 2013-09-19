#!/usr/bin/ruby -w

[ '../lib', 'lib' ].each { |d| $:.unshift(d) if File::directory?(d) }

require 'rubygems'
require 'resourceset'
require 'test/unit'
require 'yaml'

class ResourceSetTest < Test::Unit::TestCase

  def test_yaml
    res = YAML::load_file("resource_set_std.res")
  end

  def test_select
    resources = YAML::load_file("resource_set_std.res")
    r1 = resources.select(:name => "genepi")
    assert(r1.is_a?(ResourceSet))
    r2 = resources.select{ |res| res.name=="genepi"}
    assert(r1.name == r2.name)
  end

  
end


