## This is the first version of task Scheduler

require 'expectrl'
require 'rubygems'
require 'observer'


## To know if a string is a valid number
## to job detection
class String
  def is_integer?
    self.to_i.to_s == self
  end
end


class TaskManager

  MyExperiment = Experiment.instance
  ## This class will be notified from the DSL execute 
  attr_accessor :notification_mutex

  def initialize( tasks = nil )  #tasks )
    @tasks = tasks.nil? ? [] : tasks
    @registry = {} # keeps the registry of tasks
    @tasks_mutex = Mutex.new
    @notification_mutex = Mutex.new
    ## optional to start with a set of tasks
    if tasks.nil? then
      @task_from_experiment = true
    else
      @tasks.each{ |t|
        t.set_taskmanager(self)
      }
    end
  end


  def push( task )
    ## if the task already exist or have been executed it 
    ## We dont include it
    return false if not get_task( task.name).nil? or @registry.has_key?(task.name)
    task.set_taskmanager(self)
    puts "Registering task #{task.name}"
    @tasks.push( task )
  end

  def add_tasks( tasks )
    tasks.each{ |t|
      self.push(t)
    }
  end


  def execute_task( task)
    puts "Executing task #{task.name}"
    options = task.options

    if task.target.is_a?(String) and not options[:target].nil? then
      ## it is a node, cluster, or site we select the resources accordondly
      if task.target.is_integer? then
        ## it is a job so we select the resources accordondly
        puts "Executing task for a job"
        job_id = task.target
        target_nodes = options[:target].select(:id => job_id.to_i )
      else
        resource_name = task.target
        target_nodes = options[:target].select( :name => resource_name )
      end

    elsif not options[:target].nil?
      target_nodes = options[:target]
    end
    puts "Target nodes: #{target_nodes.name}"
   
    Thread.new {
      Thread.abort_on_exception=true 
      Thread.current['results'] = []
      Thread.current['hosts'] = target_nodes unless target_nodes.nil?
      task.run
      ## This part has to be commented out in order to test with the script test_taskmanager
      
      @tasks_mutex.synchronize {
        res_name = target_nodes.select_resource_h{ |res|  res.properties.has_key? :id }
        results = {res_name.name.to_sym => Thread.current['results']}
      
        MyExperiment.results.push(results)
      }
      
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
            #puts "getting task #{t_name}"
            task_depen = get_task(t_name)
            # puts "task #{task_depen.name} children: #{task_depen.children.inspect}"
            task_depen.children.each{ |c_t|
              # # puts "Trying to get task :#{c_t}"
              # puts "criteria : #{child.target}"
              suffix = c_t.to_s
              suffix.slice! (task_depen.name.to_s+"_")
              if not task.children.include?((task.name.to_s+"_"+suffix).to_sym) then
                n_t = task.split(suffix)
                puts "Task #{n_t.name} created for dependency"
                n_t.dependency.delete( t_name )
                n_t.dependency.push ( c_t )
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

    execute_task = true
    ## First thing to do we get the task from the experiment
    if @task_from_experiment
      puts "Getting tasks from Experiment"
      tasks_expe = MyExperiment.get_available_tasks
      add_tasks(tasks_expe) unless tasks_expe.nil? #if @task_from_experiment 
      ## Get a new task from the experiment if that is the case
    end

    ## This function will possibly be called by several threads so it has to be thread safe :D
    ## I think we have to assure this in the g5k api code
    new_tasks = []
    ## First we have to analyze the tasks
    tasks_changed = false
    
    @tasks.each{ |task|
      ## is the task ready to run?
      if task.async then ## task has to be treated before run it
        puts "Task : #{task.name} has to be thread before run it"
        # Two cases, asynchronously task or job asynchronously
     
        if task.job_async? and not job.nil? then   ## This tasks can be splitted several times
          puts "Creating a new task for the job"
          ## we have to create a new task for that particular job
          root_task = task.split(job.to_s)
          puts "Task : #{root_task.name} created"
          new_tasks.push(root_task)
          tasks_changed = true
      
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
    check_asynchronous_termination
   
    task_scheduled = false
  
    ## We can proceed to execute the tasks 
    @tasks.each{ |task|
      #puts "Trying to schedule task: #{task.name}"      
      if task.executable and  not @registry.has_key?(task.name) then ## the task is executable and has not been executed 
        puts "Task #{task.name} is executable"
        if task.dependency.nil? then
          puts "Scheduling new task"
          execute_task(task)
        elsif check_dependency?(task) then
          puts "Scheduling new task after checking dependency"
          execute_task(task)
        end
        task_scheduled = true
      end
      
    }
    add_tasks(new_tasks)
    puts "No task to schedule" if not task_scheduled

    ## check if a the children of a asynchronous task have finished

  end

  def check_asynchronous_termination
    @tasks.each{ |task|
      ## Two cases job synchronous
      ## we have to consul the experiment information
      ## in order to know if all the children have finished
      if task.split? and not @registry.has_key?(task.name) then ## the task has been split and it doesnt exist in the registry
        children_finished = 0
        task.children.each{ |ch_name|
          # puts "#{ch_name.class}"
          children_finished += 1 if @registry[ch_name] == "Finished"
        }
        if task.job_async
          @registry[task.name]= "Finished" if children_finished == MyExperiment.num_jobs_required
          # @registry[task.name]= "Finished" if children_finished == 3
        else 
          @registry[task.name] = "Finished" if children_finished == task.children.length
        end
      end
    }
  end

  def get_task( task_name)
    @tasks.detect{ |t| t.name == task_name }
    ## return just one object, the first one
  end

  def check_dependency_change?( task )
    return false if task.dependency.nil?
    task.dependency.each{ |d_name|
      # puts "dependency name: #{d_name}"
      d_t = get_task(d_name)
      return true if d_t.split? 
    }
    return false
  end

  def check_dependency?( task )
    puts "Checking dependency of task #{task.name}"
    return false if task.dependency.nil?
    task.dependency.each{ |d|
      return false if @registry[d] != "Finished"
    }
    return true
  end

  def delete_task( task_name )
    @tasks.delete_if{ |t| t.name == task_name }
  end

  ## This function returns the tasks that depends on a given task
  def uppper_depends( task_name )
    task_list = []
    @tasks.each { |t|
      if not t.dependency.nil? then
        task_list.push(t) if t.dependency.include?( task_name )
      end
    }
    task_list
  end

  def update(task)
    task_name = task.name
    puts "Finishing task #{task_name}"
    sleep 0.2
    @registry[task_name] = "Finished"
    schedule_new_task
  end
  
end