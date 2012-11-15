
require 'rubygems'
#Gem.path<<"#{ENV['HOME']}/.gem/"
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

### Fix me ###########
### Defining the loggin system ###########


### Class MultiIO to write log into STDOUT as well as into a file.
class MultiIO
  def initialize(*targets)
    @targets = targets
  end

  def write(*args)
    @targets.each{ |t| t.write(*args)}
  end

  def close
    @targets.each(&:close)
  end
end
##################################################################

#### Logging system #############################################
# There are Two logs:
# - log to keep simple information about actions
# - log to keep datail information of the structures of data use

log_timestamp=Time::now().to_i
actlog_fn="/tmp/Expo_log"+"_#{log_timestamp}.log"
datalog_fn="/tmp/Expo_data_log"+"_#{log_timestamp}.log"

act_logfile = File.open(actlog_fn, "w+")
data_logfile= File.open(datalog_fn, "w+")

$act_logger = Logger.new MultiIO.new(STDOUT, act_logfile)
$data_logger = Logger.new data_logfile
# $logger.level = Logger.const_get(ENV['DEBUG'] || "INFO")

#Coding a look aspect for data logger
  $data_logger.formatter = proc do |severity, datetime, progname, msg|
   output="[#{datetime}, #{severity}]: \n"+PP.pp(msg,"")  
   output
  end  

#########################################################
########### End of the logging part #####################


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

#### Fix-me ###########
$client.logger=$act_logger
$client.data_logger=$data_logger
######################

puts "Preparing resource container $all"

$all = ResourceSet::new
#### Adding this temporarly because of the asynchornous tasks ####
$atasks_mutex = Mutex::new
$atasks = Hash::new



$ssh_connector =""

#$ssh_user =""

#$ssh_timeout = ""


