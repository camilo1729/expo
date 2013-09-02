
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

def run(command)
  Console.run(command)
end

def put(data, path, options={})
  Console.put(data, path, options)
end

def free_resources(reservation)
  Console.free_resources(reservation)
end
