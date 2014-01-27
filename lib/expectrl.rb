### This class is to keep data about the experiment
require 'singleton'
require 'resourceset'
require 'logger'


class TaskResult < Hash
  
  def output
    #self.
  end
end

class Experiment

  include Singleton
  attr_accessor :resources, :logger, :tasks, :num_jobs_required, :results_raw, :tasks_names,:jobs, :variable_binding, :results
  attr_accessor :start_time, :end_time

  RESULTS_FILE = "Experiment_results"
  def initialize
    @id = 1
    @commands = []
    @resources = ResourceSet::new
    @results_raw = {}
    @results = {}
    @jobs = []
    @tasks = {}
    @tasks_names = []
    @num_jobs_required = 0 ## This will count the number of jobs required for the experiment
    @last_task = 0
    @variable_binding = nil
    @start_time = Time.now.to_i
    @end_time = nil
  end

  def run_time()
    @end_time - @start_time
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

  def save_experiment_results 
    ## Results raw will be put into the results, we rule some results out
    ## Hash pattern for results treated
    # results = {
    #   :task_1 => { [
    #     :resources => ["node1","node2","node3"],
    #     :runtime => 1212,
    #     :start_time => 1212,
    #     :end_time => 12121,
    #     :output => "Linux",
    #     :cmd => "sleep 10"
    #   }]
    # }
    @results = {}
    @results_raw.each{ | task_name, commands|
      res_lst = []
      @results[task_name.to_sym] = []
      commands.each{ |task_cmd|
        if task_cmd.has_key?(:results) then
          res_tmp = task_cmd.clone
          res_tmp.delete(:results)
          res_tmp[:output] = []
          task_cmd[:results][:output].values.flatten.each{ |ind_out|
            res_tmp[:output].push({:output => ind_out[:line], :host => ind_out[:host]})
          }
          @results[task_name.to_sym].push(res_tmp)          
          # we have to post processing it
        else ## otherwise We just continue
          @results[task_name.to_sym].push(task_cmd)          
        end
      }
    }
    ### saving results into yaml forma
    results_file = RESULTS_FILE + "#{@jobs}-#{Time.now.to_i}"
    File.open(results_file,'w+') do |f|
      f.puts(@results.to_yaml)
    end
    return true
  end

  

end

