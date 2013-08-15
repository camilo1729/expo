### experimental DSL
require 'expectrl'
require 'cmdctrl'
require 'cmdctrl_ssh' ## for ssh commands
require 'taktuk'

@variables = {}
@variables[:results] = []
# @roles = {}

def run_local(command)

  puts "executing command #{command}"
  Experiment.instance.add_command(command)
  cmd = CtrlCmd.new(command)
  cmd.run
  return [cmd.stdout,cmd.run_time]

end

def run(command)
  ## It uses taktuk as default  
  ## If a reservation is already done we assign those machines as default for hosts
  # run locally is the host is not defined
  #if @variables[:hosts].nil? then      ---- Testing with thread variables
  if Thread.current['hosts'].nil? then
    return run_local(command)
  end
  # @variables[:results] = []
  options = {:connector => 'ssh',:login => @variables[:user]}
  # hosts=@variables[:hosts]   --- Testing with thread variables
  hosts = Thread.current['hosts']
  if hosts.is_a?(ResourceSet) then
    ## this doesn't work when using with root
    cmd_taktuk=TakTuk::TakTuk.new(hosts,options)
    cmd_taktuk.broadcast_exec[command]   ## the normal behaviour if we add commands here, they will be executed in parallel.
    #puts "#{cmd_taktuk.to_cmd}"
    @variables[:results] = cmd_taktuk.run!
  elsif hosts.is_a?(String) #and @variables[:gateway]
    Experiment.instance.add_command(command)
    cmd = CmdCtrlSSH.new("",hosts,@variables[:user],@variables[:gateway])
    # @variables[:results] = cmd.run(command)
    cmd.run(command)

    Thread.current['results'].push({
      :stdout => cmd.stdout,
      :stderr => cmd.stderr, 
      :start_time => cmd.start_time, 
      :end_time => cmd.end_time
    })
    ## I need to add the command executed to the result
    #Thread.current['results'] = cmd.run(command)
  end
  
  ## This function run has to return the number of commands run succesfully
  # result_counter = 0
  # ## result_taktuk[:results][:status] is a Taktuk result object
  # result_taktuk[:results][:status].compact!.each{ |ind|
  #   ## checking for the status return
  #   result_counter+=1 if ind[:line].to_i == 0 
  # }
  
  # return result_counter
end

def put(data, path, options={})
## This is the first version of put, It will use a simple scp that
## is going to be done sequentially.

## I dont need to define a gateway, the informatin is already included in the resourceSet.

  #options = {:connector => 'ssh',:login => @variables[:user]}
  hosts=@variables[:hosts]  ## host is already check by task
  if options[:method] == "scp" then
    if hosts.is_a?(ResourceSet) then
      ## we have to iterate for each host
      hosts.each{ |node|
        command = "scp -r #{data} #{@variables[:user]}@#{node.name}:/#{path}"
        Experiment.instance.add_command(command)
        if hosts.gw == "localhost" then
          cmd = CtrlCmd.new(command)
          cmd.run
        else   ## if a gateway is define we have to use CmdCtrlSSH
          cmd = CmdCtrlSSH.new("",hosts.gw,@variables[:user],nil)
          cmd.run(command)
        end
      }
    elsif ( hosts.is_a?(String) and @variables[:gateway])
      command = "scp -r #{data} #{@variables[:user]}@#{hosts}:/#{path}"
      Experiment.instance.add_command(command)
      cmd = CmdCtrlSSH.new("",@variables[:gateway],@variables[:user],nil)
      cmd.run(command)
    else ( hosts.is_a?(String) and @variables[:gateway].nil?) ## Fix this, there is no a clean manage of the gateway
      ## This is one just one host is passed as a parameter
      command = "scp -r #{data} #{@variables[:user]}@#{hosts}:/#{path}"
      Experiment.instance.add_command(command)
      cmd = CtrlCmd.new(command)
      cmd.run
    end
  
  else 
    raise "copy method not defined"
  end
  
  ## return [cmd.stdout,cmd.run_time]

  ## this doesn't work when using with root
  
end


def add_recipe(name)
  
  ## If a reservation is already done we assign those machines as default for hosts

  options = {:connector => 'ssh',:login => @variables[:user]}
  hosts=@variables[:hosts]
  ### have to transfer the cookbook.
  ## recipe must be a tar file
  raise "Cookbook location has to be defined " if @variables[:cookbook_path].nil?
  recipe_tar = @variables[:cookbook_path]+"#{name}.tar"
  raise "Recipe directory does not exist" if not File.exists?(recipe_tar)

  cmd_taktuk=TakTuk::TakTuk.new(hosts,options)
  cmd_taktuk.broadcast_put[recipe_tar]["/tmp/#{name}.tar"]
  cmd_taktuk.broadcast_exec["tar -xf /tmp/#{name}.tar -C /tmp/"]
  ### have to install chef-solo on the machine
  cmd_taktuk.broadcast_exec["gem install chef"]
  cmd_taktuk.run!
  ### configure chef-solo to run with the cookbook transfered.
  ### Execute chef-solo on all machines.
  
end



def task(name, options={}, &block)

  puts "Executing task: #{name}"
  ## I will deactivate the notion of roles temporally
  #raise "At least one role has to be defined" if @roles.nil?
  ## Fix-me
  ## Using the variable @variables[:hosts] to pass the information
  ## to the run to where execute on.
  ## Need to fix these if it is parallel, It wont work
  # if options.empty? then
    # puts "options empty"
    # puts @roles.first[0] deactivating temporally roles
    # @variables[:hosts]=@roles.first[1]
  
  @variables[:hosts] = options[:target] if options.has_key?(:target)

  @variables[:gateway] = options[:gateway] if options.has_key?(:gateway)

  raise "User is not defined" if @variables[:user].nil?
  # if options.has_key?(:target)
  #   "target is not defined"
  #  @variables[:hosts]=options[:target]
  # else
    #raise "Neither roles nor hosts are defined" if options.has_key?(:role)
    #raise "There is not such a role #{options[:role]}" if in_roles?(:role)
   # @variables[:hosts]=@roles[options[:role].to_sym] 
  # end


  ## Now a syncronous management will be introduce
  ## if aysnchronous is passed as a parameter, the host can be the same
  ## reinitializing 
  @variables[:results] = {}
  temp_var = {}
  mutex = Mutex.new
  if options[:mode] == "asynchronous" then
    ## I have to create a thread for each node in the resources
    task_threads = []
    @variables[:hosts].each do |node|
      puts "Creating thread for host 3: #{node.name}"
      th_in = Thread.new{
        Thread.current['hosts'] = node.name
        Thread.current['results'] = []
        block.call
        mutex.synchronize {
          @variables[:results].merge!({node.name.to_sym => Thread.current['results']})
        }
        puts "Finishing task in node #{Thread.current['hosts']}"
        #puts "Results : #{Thread.current['results']}"
      }
      task_threads.push(th_in)
    end
  
    return task_threads
  else
    task_th = Thread.new{
      Thread.current['hosts'] = @variables[:hosts]
      block.call
    }
    return task_th
  end

end


def set(name, value)
  @variables[name.to_sym]=value
end

def results()
  @variables[:results]
end

### Deactivating temporally code for roles

# def in_roles?(name)
#   @roles.has_key?(name.to_sym)
# end

# def roles(name, machines)
#   @roles[name.to_sym] = machines
# end
