### experimental DSL
require 'expectrl'
require 'cmdctrl'
require 'cmdctrl_ssh' ## for ssh commands
require 'taktuk'
require 'tasks'
require 'task_manager'

## This code should include ResourceSet

## In order to avoid using Experiment.instance.method
## I can use insted another variables let's say
## MyExperiment = Experiment.instance // this is more readable 
class DSL
 
  include Singleton
  MyExperiment = Experiment.instance

  attr_reader :variables

  def initialize
    @variables = {}
    @variables[:results] = []
    @variables[:user] = nil
    @task_m = TaskManager.new
  end

  def run_local(command)

    puts "executing command #{command}"
    MyExperiment.add_command(command)
    cmd = CtrlCmd.new(command)
    cmd.run
    return [cmd.stdout,cmd.run_time]

  end

  def run(command,num_instances = nil)
    ## It uses taktuk as default  
    ## If a reservation is already done we assign those machines as default for hosts
    # run locally is the host is not defined
    if Thread.current['hosts'].nil? then
      return run_local(command)
    end
    options = {:connector => 'ssh',:login => @variables[:user]}

    hosts = Thread.current['hosts']
    if hosts.is_a?(ResourceSet) then
      ## Here, as the Expo server is on the user's machine, each resource set has to have the gateway used to enter Grid5000
      ## checking if the resource set has the gateway defined ---- Fix-me we are not checking
      #hosts.properties[:gateway] = @variables[:gateway]
      ## this doesn't work when using with root
      ## if num_instance is declared , we force the number of instances passed as argument
      num_instances.nil? ? resources = hosts : resources = hosts[0..num_instances-1]
      cmd_taktuk=TakTuk::TakTuk.new(resources,options)
      cmd_taktuk.broadcast_exec[command]   ## the normal behaviour if we add commands here, they will be executed in parallel.
      Thread.current['results'].push(cmd_taktuk.run!)
      
    elsif hosts.is_a?(String) or hosts.is_a?(Resource)#and @variables[:gateway]
      
      MyExperiment.add_command(command)
    
      hosts.is_a?(Resource) ? hosts_end = hosts.name : hosts_end = hosts
      cmd = CmdCtrlSSH.new("",hosts_end,@variables[:user],@variables[:gateway])

      # if hosts.is_a?(Resource) then
      #   cmd = CmdCtrlSSH.new("",hosts.name,@variables[:user],@variables[:gateway])
      # else
      #   cmd = CmdCtrlSSH.new("",hosts,@variables[:user],@variables[:gateway])
      # end
      @variables[:results] = cmd.run(command)
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
    
    # ## This function run has to return the number of commands run succesfully
    # # result_counter = 0
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
    resources = Thread.current['hosts'] ## host is already check by task
    if options[:method] == "scp" then
      if resources.is_a?(ResourceSet) then 

        ## nfs will decide at which level we have to copy to the frontend
        unless options[:nfs].nil? then
          
          resources.each(options[:nfs]){ |res|
            ## we copy to each nfs defined in the level of hierarchy of the resources
            command = "scp -r #{data} #{@variables[:user]}@#{res.gw}:/#{path}"
            MyExperiment.add_command(command)
            puts "Using Gateway: #{resources.gw}"
            cmd = CmdCtrlSSH.new("",resources.gw,@variables[:user],nil)
            cmd.run(command)
          }
          return
        end
        ## we have to iterate for each host
        resources.each{ |res|
          command = "scp -r #{data} #{@variables[:user]}@#{res.name}:/#{path}"
          MyExperiment.add_command(command)
          if resources.gw == "localhost" then
            cmd = CtrlCmd.new(command)
            cmd.run
          else   ## if a gateway is define we have to use CmdCtrlSSH
            cmd = CmdCtrlSSH.new("",resources.gw,@variables[:user],nil)
            cmd.run(command)
          end
        }
      elsif ( resources.is_a?(String) and @variables[:gateway])
        command = "scp -r #{data} #{@variables[:user]}@#{resources}:/#{path}"
        MyExperiment.add_command(command)
        cmd = CmdCtrlSSH.new("",@variables[:gateway],@variables[:user],nil)
        cmd.run(command)
      else ( resources.is_a?(String) and @variables[:gateway].nil?) ## Fix this, there is no a clean manage of the gateway
        ## This is one just one host is passed as a parameter
        command = "scp -r #{data} #{@variables[:user]}@#{resources}:/#{path}"
        MyExperiment.add_command(command)
        cmd = CtrlCmd.new(command)
        cmd.run
      end
      
    else 
      raise "copy method not defined"
    end
    
    ## return [cmd.stdout,cmd.run_time]

    ## this doesn't work when using with root
  
  end

  def free_resources(reservation)
    hosts = Thread.current['hosts'] ## host is already check by task
    return false if hosts.nil?
    resource = hosts.select_resource_h{ |res| res.properties.has_key? :id }
    job_id = resource.properties[:id]
    reservation.stop!(job_id)
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
  
    @variables[:hosts] = options[:target] if options.has_key?(:target)
    ## for the definition we dont need a copy
    @variables[:gateway] = options[:gateway] if options.has_key?(:gateway)
    
    raise "User is not defined" if @variables[:user].nil?
    
    ## Checking if the name exists
    raise "Task name already registered" if MyExperiment.tasks.has_key?(name)

    ## I have to define an option to the granularity of asynchronous
    options[:type] = :node if not options.has_key?(:type)
    
    ## A task object is created and registered in the experiment
    puts "Registering task: #{name}"
    
    task = Task.new(name,options,&block)
    register_task(task)

  end

  def register_task(task)
    MyExperiment.tasks[task.name.to_sym] = task
    MyExperiment.tasks_names.push(task.name.to_sym)
  end

  def run_task_manager(job=nil)
    if job.nil?
      @task_m.schedule_new_task
    else
      @task_m.schedule_new_task(job)
    end
  end
  
  def set(name, value)
    @variables[name.to_sym]=value
  end

  def results()
    @variables[:results]
  end

end


### Help class to colorize strings

class String
def black;          "\033[30m#{self}\033[0m" end
def red;            "\033[31m#{self}\033[0m" end
def green;          "\033[32m#{self}\033[0m" end
def brown;         "\033[33m#{self}\033[0m" end
def blue;           "\033[34m#{self}\033[0m" end
def magenta;        "\033[35m#{self}\033[0m" end
def cyan;           "\033[36m#{self}\033[0m" end
def gray;           "\033[37m#{self}\033[0m" end
def bg_black;       "\033[40m#{self}\0330m"  end
def bg_red;         "\033[41m#{self}\033[0m" end
def bg_green;       "\033[42m#{self}\033[0m" end
def bg_brown;       "\033[43m#{self}\033[0m" end
def bg_blue;        "\033[44m#{self}\033[0m" end
def bg_magenta;     "\033[45m#{self}\033[0m" end
def bg_cyan;        "\033[46m#{self}\033[0m" end
def bg_gray;        "\033[47m#{self}\033[0m" end
def bold;           "\033[1m#{self}\033[22m" end
def reverse_color;  "\033[7m#{self}\033[27m" end
end

