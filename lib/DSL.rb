### experimental DSL
require './expectrl'
require './cmdctrl'

def run(command)

  puts "executing command #{command}"
  Experiment.instance.add_command(command)
  cmd = CtrlCmd.new(command)
  cmd.run
  return [cmd.stdout,cmd.run_time]

end


def task(name, options={}, &block)

  puts "executing task: #{name}"
  block.call

end
