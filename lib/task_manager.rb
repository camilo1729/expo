## This is the first version of task Scheduler

require 'expectrl'
require 'rubygems'
require 'observer'
require 'colorize'

## To know if a string is a valid number
## to job detection
class String
  def is_integer?
    self.to_i.to_s == self
  end
end

class ExecutingError < StandardError
  attr_reader :object
  
  def initialize(object)
    @object = object
  end
end


class TaskManager

  MyExperiment = Experiment.instance

  ## This class will be notified from the DSL execute 
  attr_accessor :notification_mutex

  def initialize(tasks = [])  
    @tasks = tasks
    @registry = {} # keeps the registry of tasks
    @tasks_mutex = Mutex.new
    @notification_mutex = Mutex.new
    @no_tasks = false  ## just to inform that all the tasks have been executed
    @task_from_experiment = false
    ## optional to start with a set of tasks
    if @tasks.empty? then
      @task_from_experiment = true
    else
      @tasks.each{ |t|
        t.set_taskmanager(self)
      }
    end

    @logger = MyExperiment.logger
  end


  def running_tasks
    @registry.values.select{ |state| state == "Running"}.length
  end

  def tasks_registered
    return @tasks.length
  end

  def finish_tasks?
    return @no_tasks
  end

  def push(task)
    ## if the task already exist or have been executed it 
    ## We dont include it
    return false unless get_task(task.name).nil? 
    return false if @registry.has_key?(task.name)
    task.set_taskmanager(self)
    puts "Registering Task: "+ "[ #{task.name} ]".green
    @logger.info "Registering Task: "+ "[ #{task.name} ]"
    @tasks.push( task )
    ## creating the respective hash for resutls of that tasks
    MyExperiment.results[task.name.to_sym] = {} if task.split_from.nil? ## just for task that have not been split
  end

  def add_tasks(tasks)
    tasks.each{ |t|
      self.push(t)
    }
  end


  def execute_task(task)
    puts "Executing Task: "+ "[ #{task.name} ]"
    @logger.info "Executing Task: "+ "[ #{task.name} ]"
    options = task.options
    
    if task.target.is_a?(String) and not options[:target].nil? then
      ## it is a node, cluster, or site we select the resources accordondly
      if task.target.is_integer? then
        ## it is a job so we select the resources accordondly
        job_id = task.target
        puts "Spliting Task for the Job: " + "#{job_id}".red
        @logger.info "Spliting Task for the Job: " + "#{job_id}"
        target_nodes = options[:target].select(:id => job_id.to_i )
        nodes_info = target_nodes.select_resource_h{ |res|  res.properties.has_key? :id }
      else
        resource_name = task.target
        target_nodes = options[:target].select(:name => resource_name)
        nodes_info = target_nodes.select_resource_h(:name => resource_name)
      end

    elsif not options[:target].nil?
      target_nodes = options[:target]
      nodes_info = target_nodes
    else 
      nodes_info = "localhost"
    end

   
    ## Fix-me is showing in the case of resource the main name 
    puts "Nodes executing task: #{nodes_info.name}" if target_nodes.is_a?(ResourceSet)
    Thread.new {
      Thread.abort_on_exception=true 
      begin
        Thread.current['results'] = []
        Thread.current['hosts'] = target_nodes unless target_nodes.nil?
        Thread.current['task_options'] = options
        Thread.current['info_nodes'] = nodes_info unless target_nodes.nil?
        ## to avoid concurrency between tasks
        sleep(rand(20)/7.to_f)
        task.run
        exception = false
      rescue ExecutingError => e
        puts "Task: #{task.name} =>"+" Failed".red
        puts "error: #{e.object}"
        ## putting the errors
        task_name = task.split_from.nil? ? task.name : task.split_from
        results = {nodes_info => e.object}
        MyExperiment.results[task_name.to_sym].merge!(results)  ## I have to merge here          
        @registry[task.name] = "Failed"
        exception = true
      end

      unless target_nodes.is_a?(String) and exception then
        @tasks_mutex.synchronize {
          ## Get the name of the task
          ## if the task has been  split we get the name of the father
          task_name = task.split_from.nil? ? task.name : task.split_from
          results = {nodes_info => Thread.current['results']}
          MyExperiment.results[task_name.to_sym].merge!(results)  ## I have to merge here          
        }
      end
    }
    @registry[task.name] ="Running"   
  end

  def updating_dependencies()
    ## This function will update dependencies for every task

    puts "Updating dependencies....."
    new_tasks_dep = []
    @tasks.each{ |task|
      ## we loop into the dependencies
      unless task.sync then  ## unless the task is synchronous otherwise we have to update the task
        if check_dependency_change?(task) then
          task.dependency.each{ |t_name|
            puts "getting task #{t_name}"
            task_depen = get_task(t_name)
            # puts "task #{task_depen.name} children: #{task_depen.children.inspect}"
            task_depen.children.each{ |c_t|
              suffix = c_t.to_s
              suffix.slice!(task_depen.name.to_s+"_")
              if not task.children.include?((task.name.to_s+"_"+suffix).to_sym) then
                n_t = task.split(suffix)
                puts "Task : " + "[#{n_t.name}] ".green + " created for dependency"
                n_t.dependency.delete(t_name)
                n_t.dependency.push(c_t)
                new_tasks_dep.push(n_t)
              end
            }
          }
        end
      end ## unless task.sync
      }
    add_tasks(new_tasks_dep)
  end

  def schedule_new_task(job=nil)

    # execute_task = true
    ## First thing to do we get the task from the experiment
    if @task_from_experiment
      puts "Getting tasks from Experiment"
      tasks_expe = MyExperiment.get_available_tasks
      add_tasks(tasks_expe) unless tasks_expe.nil? #if @task_from_experiment 
    end

    new_tasks = []
    ## First we have to analyze the tasks
    tasks_changed = false
    
    @tasks.each{ |task|
      ## is the task ready to run?
      unless task.resource.nil? then ## task has to be treated before run it
#       puts "Task : #{task.name} has to be thread before run it"
        # Two cases, asynchronously task or job asynchronously
     
        if task.resource == :job 
          unless job.nil?
            #  if task.job_async? and not job.nil? then   ## This tasks can be splitted several times
            puts "Creating a new task for the job"
            ## we have to create a new task for that particular job
            root_task = task.split(job.to_s)
            puts "Task : "+"[#{root_task.name}]".green+ "\tcreated"
            new_tasks.push(root_task)
            tasks_changed = true
          end
      
        elsif not task.split?  
          ## If the task has been split
          ## We split according to the resources established in the resource of the task
          split_hash = { task.resource => [] }
          task_resources = task.options[:target]
          task_resources.each(task.resource){ | res |
            split_hash[task.resource].push(res.name)
          }
          new_tasks = task.split(split_hash) ## This return an array
          
          tasks_changed = true
        end
      end
    }

    ## we add the new tasks to the @task variable
    add_tasks(new_tasks)
    ## update the dependencies if it is necessary
    updating_dependencies if tasks_changed
    ## check if a the children of a asynchronous task have finished
    check_asynchronous_termination
   
    task_scheduled = false
  
    ## We can proceed to execute the tasks 
    @tasks.each{ |task|
      #puts "Trying to schedule task: #{task.name}"      
      if task.executable and  not @registry.has_key?(task.name) then ## the task is executable and has not been executed 
        # puts "Task #{task.name} is executable"
        if task.dependency.nil? then
          # puts "Scheduling new task"
          execute_task(task)
        elsif check_dependency?(task) then
          # puts "Scheduling new task after checking dependency"
          execute_task(task)
        end
        task_scheduled = true
      end
      
    }
    add_tasks(new_tasks)
    unless task_scheduled 
      puts "No task to schedule".brown 
      @no_tasks = true
    end

  end

  def check_asynchronous_termination
    @tasks.each{ |task|
      ## Two cases job synchronous
      ## we have to consult the experiment information
      ## in order to know if all the children have finished
      if task.split? and not @registry.has_key?(task.name) then ## the task has been split and it doesnt exist in the registry
        children_finished = 0
        task.children.each{ |ch_name|
          # puts "#{ch_name.class}"
          children_finished += 1 if @registry[ch_name] == "Finished"
        }
        if task.resource == :job
          @registry[task.name]= "Finished" if children_finished == MyExperiment.num_jobs_required
        else 
          if check_dependency?(task) then
            @registry[task.name] = "Finished" if children_finished == task.children.length
          end
        end
      end
    }
  end

  def get_task(task_name)
    @tasks.detect{ |t| t.name == task_name }
    ## return just one object, the first one
  end

  def check_dependency_change?(task)
    # puts "Checking depdency for task : #{task.name}"
    return false if task.dependency.nil?
    task.dependency.each{ |d_name|
    #  puts "dependency name: #{d_name}"
      d_t = get_task(d_name)
      return true if d_t.split? 
    }
    return false
  end

  def check_dependency?(task)
    # puts "Checking dependency of task #{task.name}"
    return false if task.dependency.nil?
    task.dependency.each{ |d|
      return false if @registry[d] != "Finished"
    }
    return true
  end

  def delete_task(task_name)
    @tasks.delete_if{ |t| t.name == task_name }
  end

  ## This function returns the tasks that depends on a given task
  def uppper_depends(task_name)
    task_list = []
    @tasks.each { |t|
      if not t.dependency.nil? then
        task_list.push(t) if t.dependency.include?(task_name)
      end
    }
    task_list
  end

  def update(task)
    task_name = task.name
    puts "Task: "+ "#{task_name}\t".cyan + "[ DONE ]".green + " In #{task.run_time.round(3)} Seconds".blue
    @logger.info "Task: "+ "#{task_name}\t" + "[ DONE ]" + " In #{task.run_time.round(3)} Seconds"
    sleep(rand(10)/17.to_f)
    @registry[task_name] = "Finished"
    schedule_new_task
  end
  
end
