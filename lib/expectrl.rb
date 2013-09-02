### This class is to keep data about the experiment
### This is going to be a singleton class :)
require 'singleton'
require 'resourceset'
require 'logger'
class Experiment
  include Singleton
  attr_accessor :resources, :logger, :tasks, :num_jobs_required, :results, :jobs_2, :tasks_names
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
    @num_jobs_required = 0 ## This will count the number of jobs required for the experiment
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

  ## This methods returns all the avaiable task registered so far
  ## in the experiment.
  def get_available_tasks
    tasks_to_return = []
    @tasks_names.each{ |t_name|
      tasks_to_return.push(@tasks[t_name])
    } 
    return tasks_to_return
  end

end

