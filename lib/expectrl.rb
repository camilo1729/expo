### This class is to keep data about the experiment
### This is going to be a singleton class :)
require 'singleton'
require 'resourceset'
require 'logger'
class Experiment
  include Singleton
  attr_accessor :resources, :logger, :tasks, :base_task, :num_jobs_required, :results, :jobs_2
  def initialize
    @id = 1
    @commands = []
    @resources = ResourceSet::new
    @logger = Logger.new("/tmp/Expo_log_#{Time.now.to_i}.log")
    @results = []
    @jobs = {}
    @jobs_2 = [] #temporal variable
    @tasks = {}
    @tasks_names = []
    @base_task = nil
    @num_jobs_required = 0 ## This will count the number of jobs required for the experiment
                             ## It will depend on the reservation
    @last_task = 0
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

  ## This methods returns a task in order  
  def get_task
    task_to_return = @tasks[@tasks_names[@last_task]] 
    @last_task += 1 if not task_to_return.nil? 
  end

end

