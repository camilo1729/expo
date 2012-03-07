require 'rubygems'
Gem.path<<"#{ENV['HOME']}/.gem/"
#require 'termios'
require 'optparse'
require 'resourceset'
require 'taskset'
require 'thread'
#puts Gem.path
include Expo

$RMI='none'
port = 15783

require 'expctrl'
require 'taktuk_wrapper'
require 'yaml'

#puts ENV['GEM_HOME']
#puts ENV['RUBYLIB']
#puts Gem.path
puts "Welcome to Expo Interactive Mode"
puts "All the libraries have been loaded"

puts "Opening Experiment"

$client = ExpCtrlClient::new("localhost:17281")

$client.open_experiment

puts "Preparing resource container $all"

$all = ResourceSet::new

$ssh_connector =""


