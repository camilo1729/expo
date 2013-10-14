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

  attr_reader :variables, :task_m

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

  def run(command,params={})
    ## To ease the declaration
    if params.is_a?(Symbol) then
      temp = params
      params = {temp => []}
    end
    ## options
    ## { :ins_per_machine = number,
    ## { :ins_per_resource_set =
    ## It uses taktuk as default  
    ## If a reservation is already done we assign those machines as default for hosts

    # run locally is the host is not defined
    if Thread.current['hosts'].nil? then
      return run_local(command)
    end

    options = {:connector => 'ssh',:login => @variables[:user]}


    ## Getting variables from the executing task    
    hosts = Thread.current['hosts']
    task_options = Thread.current['task_options']

    if hosts.is_a?(ResourceSet) then
      ## Here, as the Expo server is on the user's machine, each resource set has to have the gateway used to enter Grid5000
      ## checking if the resource set has the gateway defined ---- Fix-me we are not checking
      #hosts.properties[:gateway] = @variables[:gateway]
      ## this doesn't work when using with root
      ## if num_instance is declared , we force the number of instances passed as argument
      resources = hosts
      resources = hosts[0..params[:ins_per_resources]-1]   if params[:ins_per_resources] #I have to find a better way to do this
     
      if params[:ins_per_machine] then
        if command.is_a?(Array) then
          ## We assinged commands to each individual node
          resources.each{ |node|
            node.properties[:multiplicity] = params[:ins_per_machine]
            node.properties[:cmd] = command  
          }
        else
          resources.each{ |node|
            node.properties[:multiplicity] = params[:ins_per_machine]
            node.properties[:cmd] = command
          }
        end
        
      end
   
      cmd_taktuk=TakTuk::TakTuk.new(resources,options)
      cmd_taktuk.broadcast_exec[command]   ## the normal behaviour if we add commands here, they will be executed in parallel.
      taktuk_result = cmd_taktuk.run!
      
      ## I have to analyze the result
      ## Sometime we need to check something with a bash command and we dont want to raise an error
      
      taktuk_result[:results][:status].compact!.each{ |ind|
        ## checking for the status return
        if ind[:line].to_i != 0 then
          raise ExecutingError.new(taktuk_result[:results][:error]) unless params[:no_error]
          return false
        end
      }
      

      ## if a tag is activated we tag the results for an easy management
        if params[:results_label] then
          tag_hash = {:tag => params[:results_label] }
          taktuk_result.merge!(tag_hash)
        end
      Thread.current['results'].push(taktuk_result)
      return true
      
    elsif hosts.is_a?(String) or hosts.is_a?(Resource)#and @variables[:gateway]
      
      MyExperiment.add_command(command)
      
      if hosts.is_a?(Resource) then 
        hosts_end = hosts.name 
        gateway = hosts.properties[:gateway]
      else
        hosts_end = hosts
        gateway = Thread.current['task_options'][:gateway]
      end

      cmd = CmdCtrlSSH.new("",hosts_end,@variables[:user],gateway)

      cmd.run(command)

      raise ExecutingError if cmd.exit_status != 0

      ## Results for the ssh execution are not implemented yet, 
      ## We have to act on the task_manager code execute task part
      Thread.current['results'].push({
                                       :stdout => cmd.stdout,
                                       :stderr => cmd.stderr, 
                                       :start_time => cmd.start_time, 
                                       :end_time => cmd.end_time
                                     })
    end
    
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
            command = "scp -r #{data} #{@variables[:user]}@#{res.gw}:#{path}"
            MyExperiment.add_command(command)
            puts "Using Gateway: #{resources.gw}"
            cmd = CmdCtrlSSH.new("",resources.gw,@variables[:user],nil)
            cmd.run(command)
          }
          return
        end
        ## we have to iterate for each host
        resources.each{ |res|
          command = "scp -r #{data} #{@variables[:user]}@#{res.name}:#{path}"
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
        command = "scp -r #{data} #{@variables[:user]}@#{resources}:#{path}"
        MyExperiment.add_command(command)
        cmd = CmdCtrlSSH.new("",@variables[:gateway],@variables[:user],nil)
        cmd.run(command)
      else ( resources.is_a?(String) and @variables[:gateway].nil?) ## Fix this, there is no a clean manage of the gateway
        ## This is one just one host is passed as a parameter
        command = "scp -r #{data} #{@variables[:user]}@#{resources}:#{path}"
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

  def get(path, data, options={})
    ## This is the first version of get, It will use a simple scp that
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
            if options[:distinguish] == true then  ## This is for managing the getting of results when the filename is equal
              puts "Distinguish activated"
              command = "scp -r #{@variables[:user]}@#{res.gw}:#{path} #{data}#{res.name}"
            else
              command = "scp -r #{@variables[:user]}@#{res.gw}:#{path} #{data}"
            end
       
            MyExperiment.add_command(command)
            puts "Using Gateway: #{resources.gw}"
            cmd = CmdCtrlSSH.new("",resources.gw,@variables[:user],nil)
            cmd.run(command)
          }
          return
        end
        ## we have to iterate for each host
        resources.each{ |res|
          command = "scp -r #{@variables[:user]}@#{res.name}:#{path} #{data}"
          MyExperiment.add_command(command)
          if resources.gw == "localhost" then
            cmd = CtrlCmd.new(command)
            cmd.run
          else   ## if a gateway is define we have to use CmdCtrlSSH
            cmd = CmdCtrlSSH.new("",resources.gw,@variables[:user],nil)
            cmd.run(command)
          end
        }
      elsif (resources.is_a?(String) and @variables[:gateway])
        command = "scp -r #{@variables[:user]}@#{resources}:#{path} #{data}"
        MyExperiment.add_command(command)
        cmd = CmdCtrlSSH.new("",@variables[:gateway],@variables[:user],nil)
        cmd.run(command)
      else (resources.is_a?(String) and @variables[:gateway].nil?) ## Fix this, there is no a clean manage of the gateway
        ## This is one just one host is passed as a parameter
        if options[:distinguish] == true then  ## This is for managing the getting of results when the filename is equal
          puts "Distinguish activated"
          command = "scp -r #{@variables[:user]}@#{resources}:#{path} #{data}#{resources}"
        else
          command = "scp -r #{@variables[:user]}@#{resources}:#{path} #{data}"
        end
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


  def get_variable(var)
    ## This can be used in general any variable will be passed as Thread.current['var']
    return Thread.current[var]
  end

  def set_variable(var,value)
    Thread.current[var] = value
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
  
    @variables[:hosts] = options[:target] if options.has_key?(:target)
    ## for the definition we dont need a copy
    @variables[:gateway] = options[:gateway] if options.has_key?(:gateway)
    
    raise "User is not defined" if @variables[:user].nil?
    
    ## Checking if the name exists
    raise "Task name already registered" if MyExperiment.tasks.has_key?(name)

    ## I have to define an option to the granularity of asynchronous
    ##options[:split_into] = :node if not options.has_key?(:split_into)
    
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



