### experimental DSL
require 'expectrl'
require 'cmdctrl'
require 'cmdctrl_ssh' ## for ssh commands
require 'taktuk'
require 'tasks'
require 'task_manager'
require 'pry'
## This code should include ResourceSet

## In order to avoid using Experiment.instance.method
## MyExperiment = Experiment.instance // this is more readable



class DSL

  include Singleton
  include Log4r
  MyExperiment = Experiment.instance

  attr_reader :variables,:task_manager,:exp_variables,:exp_tasks

  def initialize
    @variables = {}
    @variables[:results] = []
    @variables[:user] = nil
    @logger = Log4r::Logger['Expo_log']
    @task_manager = TaskManager.new
    @variables_set = false
    @exp_variables = ""
    @exp_tasks = ""
  end

  def connection(options={})
    ## we have to check the password-less accessability of the gateway
    type = options[:type]
    if type == "Grid5000" then
      return ExpoEngine.new(@variables[:gateway],@variables[:public_key])
    elsif type =="Plain" then
      resources = PlainNodes.new(options[:nodes_file])
      resources.create
    end
  end


  def run(command,options={})

    info_resources = []
    info_resources = Thread.current['info_resources']

#     if options[:target].nil? then
# #      info_resources = Thread.current['info_resources']
#     elsif options[:target].is_a?(String) then
#       info_resources = options[:target]
#     elsif options[:target].is_a?(Resource) then
#       info_resources = options[:target].name
#     else
#       options[:target].each{ |node| info_resources.push(node.name)}
#     end

   # If gateway user is not declared it is suppose to use the same user for connecting to the frontend
    @variables[:gw_user] ||= @variables[:user]

    ## To ease the declaration
    ## options
    ## { :ins_per_machine = number,
    ## It uses taktuk as default
    ## If a reservation is already done we assign those machines as default for hosts

    # run locally if the host is not defined and parameter target is not declared
    if Thread.current['resources'].nil? and options[:target].nil? then
      MyExperiment.add_command(command)
      cmd = CtrlCmd.new(command)
      cmd.run
      if cmd.status != 0 then
        raise ExecutingError.new(cmd.stderr) unless options[:no_error]
        return false
      end
      Thread.current['results'].push({
                                       :resources => info_resources,
                                       :stdout => cmd.stdout,
                                       :stderr => cmd.stderr,
                                       :start_time => cmd.start_time,
                                       :end_time => cmd.end_time,
                                       :run_time => cmd.end_time - cmd.start_time,
                                       :cmd => command
                                     })
      return true
    end





    ## Getting variables from the executing task
    if options[:target].nil? then
      resources = Thread.current['resources']
      @logger.debug "Command generated : #{resources.make_taktuk_command}"
    else
      resources = options[:target]
    end

    resources = resources.first if options[:once] ## We execute just once

    task_options = Thread.current['task_options']


    if resources.is_a?(ResourceSet) then ## Using TakTuk in parallel
      ## Here, as the Expo server is on the user's machine, each resource set has to have the gateway used to enter Grid5000
      ## checking if the resource set has the gateway defined ---- Fix-me we are not checking
      ## if num_instance is declared , we force the number of instances passed as argument
      taktuk_options = {:connector => 'ssh',:login => @variables[:gw_user]}
      exe_resources = resources
      if options[:ins_per_machine] then
        if command.is_a?(Array) then
          ## We assinged commands to each individual node
          exe_resources.each{ |node|
            node.properties[:multiplicity] = options[:ins_per_machine]
            node.properties[:cmd] = command
          }
        else
          exe_resources.each{ |node|
            node.properties[:multiplicity] = options[:ins_per_machine]
            node.properties[:cmd] = command
          }
        end

      end

      cmd_taktuk=TakTuk::TakTuk.new(exe_resources,taktuk_options)
      @logger.debug "Executing command: #{command}"
      cmd_taktuk.broadcast_exec[command]
      ## the normal behaviour if we add commands here, they will be executed in parallel.
      taktuk_result = cmd_taktuk.run!  # bug I'm not able to detect that taktuk is not installed
      ## I have to analyze the result
      ## Sometimes we need to check something with a bash command and we dont want to raise an error
      taktuk_result[:results][:status].compact!.each{ |ind|
        ## checking for the status return
        if ind[:line].to_i != 0 then
          raise ExecutingError.new(taktuk_result[:results][:error]) unless options[:no_error]
          return false
        end
      }

      ## if a tag is activated we tag the results for an easy management
      if options[:results_label] then
        @logger.debug "Tag activated"
        tag_hash = {:tag => options[:results_label] }
        taktuk_result.merge!(tag_hash)
      end

      taktuk_result[:results][:taktuk]= true

      Thread.current['results'].push(taktuk_result.merge!(:resources => info_resources))

      return true

    # When the target is a Resource or a simple host represented by a String
    elsif resources.is_a?(String) or resources.is_a?(Resource)

      @logger.debug "Generating SSH command for #{command}"
      MyExperiment.add_command(command)

      if resources.is_a?(Resource) then
        exe_resources = resources.name
        gateway = resources.properties[:gateway]
      else
        exe_resources = resources
        gateway = Thread.current['task_options'][:gateway]
      end

      if gateway.nil? then
        cmd = CmdCtrlSSH.new("",exe_resources,@variables[:user])
      else
        cmd = CmdCtrlSSH.new("",exe_resources,@variables[:user],gateway,@variables[:gw_user])
      end

      cmd.run(command)

      if cmd.exit_status != 0 then
        @logger.error "Error from cmd: #{cmd.stderr}"
        raise ExecutingError unless options[:no_error]
        return false
      end

      ## Results for the ssh execution are not implemented yet,
      ## We have to act on the task_manager code execute task part
      Thread.current['results'].push({
                                       :resources => info_resources,
                                       :stdout => cmd.stdout,
                                       :stderr => cmd.stderr,
                                       :start_time => cmd.start_time,
                                       :end_time => cmd.end_time,
                                       :cmd => cmd.cmd,
                                       :run_time => cmd.end_time - cmd.start_time
                                     })
    end

  end


  def put(data, path, options={})
    ## This is the first version of put,
    ## It will use a simple scp that is going to be done sequentially.

    # if gate way user is not declare it is supposed to use the same user
    # for connectiing to the frontend
    @variables[:gw_user] = @variables[:user] if @variables[:gw_user].nil?

    ## I dont need to define a gateway, the informatin is already included in the resourceSet.

    if options[:target].nil? then
      resources = Thread.current['resources']
    else
      resources = options[:target]
    end

    options[:method] ||= "scp" # Assigned scp as a default method for copying


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
          @logger.info "command_generated : #{command}"
          MyExperiment.add_command(command)
          if resources.gw == "localhost" then
            cmd = CtrlCmd.new(command)
            cmd.run
          else   ## if a gateway is define we have to use CmdCtrlSSH
            cmd = CmdCtrlSSH.new("",resources.gw,@variables[:gw_user],nil)
            cmd.run(command)
          end
        }
      elsif resources.is_a?(Resource) then
          command = "scp -r #{data} #{@variables[:user]}@#{resources.name}:#{path}"
          MyExperiment.add_command(command)
          if resources.gw == "localhost" then
            cmd = CtrlCmd.new(command)
            cmd.run
          else   ## if a gateway is define we have to use CmdCtrlSSH
            cmd = CmdCtrlSSH.new("",resources.gw,@variables[:gw_user],nil)
            cmd.run(command)
          end

      elsif (resources.is_a?(String) and @variables[:gateway])
        if resources == @variables[:gateway] ## we are copying to the gateway
          command = "scp -r #{data} #{@variables[:gw_user]}@#{resources}:#{path}"
          MyExperiment.add_command(command)
          cmd = CtrlCmd.new(command)
        else
          command = "scp -r #{data} #{@variables[:user]}@#{resources}:#{path}"
          MyExperiment.add_command(command)
          cmd = CmdCtrlSSH.new("",@variables[:gateway],@variables[:gw_user],nil)
        end
          cmd.run(command)
      elsif(resources.is_a?(String) and @variables[:gateway].nil?)
        ## Fix this, there is no a clean manage of the gateway
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


  def msg(message)
    @logger.info "From Task: #{message}"
  end


  def get(path, data, options={})
    ## This is the first version of get, It will use a simple scp that
    ## is going to be done sequentially.

    ## I dont need to define a gateway, the informatin is already included in the resourceSet.
    # if gate way user is not declare it is suppose to use the same user for connectiing to the frontend
    @varibles[:gw_user] = @variables[:user] if @variables[:gw_user].nil?


    if options[:target].nil? then
      resources = Thread.current['resources']
    else
      resources = options[:target]
    end


    options[:method] ||= "scp"

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
            @logger.info "Using Gateway #{resources.gw}"
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
            cmd = CmdCtrlSSH.new("",resources.gw,@variables[:gw_user],nil)
            cmd.run(command)
          end
        }
      elsif resources.is_a?(Resource) then
        command = "scp -r #{@variables[:user]}@#{resources.name}:#{path} #{data}"
          MyExperiment.add_command(command)
          if resources.gw == "localhost" then
            cmd = CtrlCmd.new(command)
            cmd.run
          else   ## if a gateway is define we have to use CmdCtrlSSH
            cmd = CmdCtrlSSH.new("",resources.gw,@variables[:gw_user],nil)
            cmd.run(command)
          end
      elsif (resources.is_a?(String) and @variables[:gateway])
        command = "scp -r #{@variables[:user]}@#{resources}:#{path} #{data}"
        MyExperiment.add_command(command)
        cmd = CmdCtrlSSH.new("",@variables[:gateway],@variables[:user],nil)
        cmd.run(command)
      else (resources.is_a?(String) and @variables[:gateway].nil?) ## Fix this, there is no a clean manage of the gateway
        ## This is one just one host is passed as a parameter
        if options[:distinguish] == true then  ## This is for managing the getting of results when the filename is equal
          puts "Distinguish activated"
          command = "scp -r #{@variables[:gw_user]}@#{resources}:#{path} #{data}#{resources}"
        else
          command = "scp -r #{@variables[:gw_user]}@#{resources}:#{path} #{data}"
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


### This method is specific to Grid5000
  def free_resources(reservation)
    hosts = Thread.current['resources'] ## host is already check by task
    return false if hosts.nil?
    return false unless hosts.is_a?(ResourceSet)
    ### Getting the jobs identifiers
    resource = hosts.select_resource_h{ |res| res.properties.has_key? :id } # just to know at which level the jobs has been submitted either cluster or site
    jobs_id = []
    hosts.each(resource.type){ |resource|  jobs_id.push(resource.properties[:id]) }
    reservation.stop!(jobs_id)
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
    ### configure chef-solo to run with the cookbook transferred.
    ### Execute chef-solo on all machines.

  end



  def task(name, options={}, &block)

    ## for the definition we dont need a copy
    @variables[:gateway] = options[:gateway] if options.has_key?(:gateway)

    options[:res_granularity] = options[:each]

    raise "User is not defined" if @variables[:user].nil?

    ## if the target thas the form 122112_method it means that
    ## The resourset method was not able to send a reference,
    ## Therefore it has to be evaluated later

    regexp = /^(\d*)_(\w*)$/
    if options[:target].is_a?(String) then
      if values = regexp.match(options[:target]) then
        var_id = values[1].to_i
        var_method = values[2]
        var_name=look_variable_by_id(var_id,MyExperiment.variable_binding)
        new_target="#{var_name}.#{var_method}"
        @logger.info "New_target #{new_target} for Task: #{name}"
        @logger.info "Activating lazy evaluation"
        options[:lazy]=true
        #options[:target]=new_target
        options[:target]=[var_name,var_method]
      end
    end

    options[:res_granularity] = @variables[:res_granularity]  unless @variables[:res_granularity].nil?

    if options[:target].nil? then
      # We are running on the local machine
      options[:sync] = true # We make the task synchronous
    end

    options[:res_granularity] = nil if ( options[:target].nil? || options[:target].is_a?(String))


    ## This is a local task resource granularity does not apply
    ## Checking if the name exists
    raise "Task name already registered" if MyExperiment.tasks.has_key?(name)

    ## A task object is created and registered in the experiment
    task = Task.new(name,options,&block)
    register_task(task)

  end

  def register_task(task)
    MyExperiment.tasks[task.name.to_sym] = task
    MyExperiment.tasks_names.push(task.name.to_sym)
  end

  # def run_task_manager(job=nil)
  #   if job.nil?
  #     @task_m.schedule_new_task
  #   else
  #     @task_m.schedule_new_task(job)
  #   end
  # end

  def run_task(task_name)
    @task_manager.execute_task(@task_manager.get_task(task_name))
  end


  def load_experiment(file_path)
    @logger.info "Reading Experiment Definition file !!! .."
    @exp_variables = ""
    @exp_tasks = ""
    flag = false
    file = File.new(file_path, "r")
    count = 0
    @logger.info "Reading experiment variables"
    while (line = file.gets)
      unless (line.chop == "start_task_definition" or flag) then
        @exp_variables+= "#{line}"
        # print "Reading experiment variables ...#{count}".cyan
        # print 13.chr
        # count = count + 1
      end
      @exp_tasks += "#{line}" if flag
      if line.chop =="start_task_definition" then
        @logger.info "Reading experiment tasks"
        flag = true
      end
    end

    raise "There is not task definition, please put: start_task_definition at the begining of your task definition" unless flag
    @logger.info "Experiment description loaded ..."
  end

  def start_experiment(options={})
    ## First dealing with description file loading and proper experiment variables handling
    variable_binding = binding
    eval(@exp_variables,variable_binding)

    ### Perfrom some checks with connectivity
    # ssh -o ConnectTimeout 5 gateway in order to know that the gateway to access the platform is accesible
    if @variables[:gateway] then
      @logger.info "Checking the accessability of the defined gateway: #{@variables[:gateway]}"
      test_cmd = "ssh -o ConnectTimeout=5 #{@variables[:gateway]} hostname"
      @logger.info "With command: #{test_cmd}"
      cmd = CtrlCmd.new(test_cmd)
      cmd.run
      if cmd.status > 0 then
        @logger.error "Error Experiment gateway is inaccessible"
        @logger.fatal "Exiting... "
        return false
      else
        @logger.info "Gateway connectivity [OK].."
      end
    end
    MyExperiment.variable_binding = variable_binding
    set_experiment_variables(variable_binding)
    eval(@exp_tasks, variable_binding) ## loading Expo tasks

    ### By default the experiment is run under a FiFo scheduling
    ## setting the dependencies of tasks for fifo
    previous_task_name = nil
    previous_task_name_parallel = nil ## This is for parallel Tasks
    options[:schedule] ||= :fifo

    if options[:schedule] == :fifo then
      MyExperiment.tasks.each{ |taskname, task|

        unless task.options[:parallel] then
          task.dependency.push(previous_task_name) unless previous_task_name.nil?
          previous_task_name_parallel = taskname ## This is for parallel Tasks
        else
          task.dependency.push(previous_task_name_parallel)
        end
        previous_task_name = taskname
      }
    end
    @task_manager.schedule_new_task
  end



  def set_experiment_variables(exp_binding)
    ### Here we deal with the case when value make reference to MyExperiment.resources
    ## Because this will be created dinamically
    #variables_binding = binding  #This is the variable binding for setting the resourceset at execution time
    @variables.each{ |name,value|
       regexp = /.*\/.*/
      # Testing if has a ruby valid variable name
      string_flag = true if value.is_a?(String)
      if string_flag == true then
        if not regexp.match(value.to_s) then
          if eval("defined? #{value}",exp_binding) then
            @logger.info "Setting already variable => #{name.to_s}=#{value}"
            eval("#{name.to_s}=#{value}",exp_binding)
          else
            @logger.info "Setting variable => #{name.to_s}=\"#{value}\""
            eval("#{name.to_s}=\"#{value}\"",exp_binding)
          end
        else
          @logger.info "Setting variable => #{name.to_s}=\"#{value}\""
          eval("#{name.to_s}=\"#{value}\"",exp_binding)
        end
      end
    }
    @variables_set = true
  end

  def look_variable_by_id(var_id,variable_binding)
    ## looking for object id among the variables defined for the experiment
    @variables.each{ |name, value|
      obj_id=eval("#{name.to_s}.object_id",variable_binding)
      return name.to_s if var_id==obj_id
    }
    return nil
  end

  def set(name, value)
    @variables[name.to_sym]=value
  end

  def results()
    @variables[:results]
  end


end
