require 'rubygems'
require 'optparse'
require 'log4r-color'

ROOT_DIR= File.expand_path('../..',__FILE__)
BIN_DIR= File.join(ROOT_DIR,"bin")
LIB_DIR= File.join(ROOT_DIR,"lib")
$LOAD_PATH.unshift LIB_DIR unless $LOAD_PATH.include?(LIB_DIR)

## Here I will include the DSL commands
require 'DSL'

MyExperiment = Experiment.instance

include Log4r

expo_logger = Log4r::Logger.new('Expo_log')

format = Log4r::PatternFormatter.new(:pattern => '%d %5l %11c: %M')
console_output = Log4r::ColorOutputter.new 'color', {
  :colors =>   { 
    :debug  => :light_blue, 
    :info   => :light_blue, 
    :warn   => :yellow, 
    :error  => :red, 
    :fatal  => {:color => :red, :background => :white} 
  } ,
  :formatter => format,
}

expo_log_file = Log4r::FileOutputter.new('logtest', :filename =>  "Expo_#{Time.now.to_i}.log")

expo_logger.outputters = [console_output,expo_log_file] 

Console = DSL.instance


def task(name, options={}, &block)
  Console.task(name,options, &block)
end

def execute(task_name,job_id = nil)
  Console.execute(task_name,job_id)
end

def set(name, value)
  Console.set(name,value)
end

def run(command,params = {})
  Console.run(command,params)
end

def check(command)
  ret = Console.run(command,:no_error)
  if ret == false then
    return ret 
  else
    return true
  end
end

def put(data, path, options={})
  Console.put(data, path, options)
end

def get(path, data, options={})
  Console.get(path, data, options)
end

def free_resources(reservation)
  Console.free_resources(reservation)
end

def get_variable(var)
  Console.get_variable(var)
end

def set_variable(var,value)
  Console.set_variable(var,value)
end

def run_task(task_name)
  Console.run_task(task_name)

  ## bug, when trying to rexecute a task with the argument split,
  # it seems that it doesnt take into account this argument anymore

  # This bug is due to the dynamic partitioning of the tasks.
  # when a task is already partitioned , I cannot paritined again, therefore it will execute ingoring the argument split
end

def load_experiment(file_path)
  Console.load_experiment(file_path)
end

def start_experiment()
  Console.start_experiment()
end

def set_experiment_variables()
  Console.set_experiment_variables()
end

## if a file is passed as a parameter
if ARGV.length == 1
  load_experiment(ARGV[0])
  sleep 2
  start_experiment()
  until Console.task_manager.finish_tasks? do
    puts "Executing Experiment waiting for  [ #{Console.task_manager.running_tasks} ] Task running ...".cyan
    sleep 20
  end
  expo_logger.info "Experiment has finished  :::"
  expo_logger.info "Saving resuls ...:"
  MyExperiment.save_experiment_results
  MyExperiment.end_time = Time.now.to_i
  expo_logger.info "Total Experiment run time: #{MyExperiment.run_time} secs"
end
