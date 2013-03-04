### experimental DSL
require './expectrl'
require './cmdctrl'
require './taktuk'

@variables={}

def run(command)

  puts "executing command #{command}"
  Experiment.instance.add_command(command)
  cmd = CtrlCmd.new(command)
  cmd.run
  return [cmd.stdout,cmd.run_time]

end

def run_remote(command)
  raise "user is not defined" if @variables[:user].nil?
  raise "hosts is not defined" if @variables[:hosts].nil?

  options = {:connector => 'ssh',:login => @variables[:user]}
  hosts=@variables[:hosts]
  cmd_taktuk=TakTuk::TakTuk.new(hosts,options)
  cmd_taktuk.broadcast_exec[command]
  cmd_taktuk.run!
end


def task(name, options={}, &block)

  puts "executing task: #{name}"
  block.call

end


def set(name, value)
  @variables[name.to_sym]=value
end

