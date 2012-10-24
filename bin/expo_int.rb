
require 'rubygems'
Gem.path<<"#{ENV['HOME']}/.gem/"
#require 'termios'
require 'optparse'
ROOT_DIR= File.expand_path('../..',__FILE__)
BIN_DIR= File.join(ROOT_DIR,"bin")
LIB_DIR= File.join(ROOT_DIR,"lib")


$LOAD_PATH.unshift LIB_DIR
ENV['RUBYLIB'] = LIB_DIR
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

if File.exist?("#{ENV['HOME']}/.expctrl_server") then
  config = YAML::load(File.open("#{ENV['HOME']}/.expctrl_server"))
  port = config['port'] if config['port']
  $RMI = config['rmi_protocol'] if config['rmi_protocol']
  $POLLING =  config['polling'] if config['polling']
end

puts "The port is #{port}"

#puts ENV['GEM_HOME']
#puts ENV['RUBYLIB']
#puts Gem.path
puts "Welcome to Expo Interactive Mode"
puts "All the libraries have been loaded"

puts "Opening Experiment"

$client = ExpCtrlClient::new("localhost:#{port}")

$client.open_experiment

puts "Preparing resource container $all"

$all = ResourceSet::new
#### Adding this temporarly because of the asynchornous tasks ####
$atasks_mutex = Mutex::new
$atasks = Hash::new


$ssh_connector =""

#$ssh_user =""

#$ssh_timeout = ""


