### This class is to keep data about the experiment
### This is going to be a singleton class :)
require 'singleton'
require 'resourceset'
require 'logger'
class Experiment
  include Singleton
  attr_accessor :resources, :logger
  def initialize
    @id = 1
    @commands = []
    @resources = ResourceSet::new
    @logger = Logger.new("/tmp/Expo_log_#{Time.now.to_i}.log")
    @jobs = {}
    # :number => 'state'
  end
  
  def add_command(command)
    @commands.push(command)
  end

  ### assign resources
  def add_resources(resources)
    @resources = resources
  end
   
  def show_commands
    @commands.each{|cmd| puts cmd}
  end

end

