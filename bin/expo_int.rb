
require 'rubygems'
#Gem.path<<"#{ENV['HOME']}/.gem/"
#require 'termios'
require 'optparse'
ROOT_DIR= File.expand_path('../..',__FILE__)
BIN_DIR= File.join(ROOT_DIR,"bin")
LIB_DIR= File.join(ROOT_DIR,"lib")
$LOAD_PATH.unshift LIB_DIR unless $LOAD_PATH.include?(LIB_DIR)

## Here I will include the DSL commands

require 'DSL'
require 'colorize'

Console = DSL.instance

MyExperiment = Experiment.instance

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

## if a file is passed as a parameter
# if ARGV.length == 1
# #  load(ARGV[0])
#   sleep 5
#   Console.run_task_manager ### running the first task because now everything is a task
#   until Console.task_m.finish_tasks? do
#     puts "Executing Experiment waiting for  [ #{Console.task_m.running_tasks} ] Task running ...".cyan
#     sleep 30
#   end
#   puts "Experiment has finished  :::".cyan
# end
