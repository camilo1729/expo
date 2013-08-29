## This is the first version of task Scheduler

require 'expectrl'
require 'rubygems'
require 'observer'


class TaskManager

  MyExperiment = Experiment.instance
  ## This class will be notified from the DSL execute 
  attr_accessor :notification_mutex

  def initialize( tasks = nil )  #tasks )
    @tasks = tasks.nil? ? [] : tasks
    @registry = {} # keeps the registry of tasks
    @tasks_mutex = Mutex.new
    ## optional to start with a set of tasks
    if tasks.nil? then
      @task_from_experiment = true
    else
      @tasks.each{ |t|
        t.set_taskmanager(self)
      }
    end
    @notification_mutex = Mutex.new
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
    if task.target.is_a?(Fixnum) and not options[:target].nil? then
      ## it is a job so we select the resources accordondly
      job_id = task.target
      target_nodes = options[:target].select(:id => job_id )
    elsif task.target.is_a?(String) and not options[:target].nil? then
      ## it is a node, cluster, or site we select the resources accordondly
      resource_name = task.target
      target_nodes = options[:target].select( :name => resource_name )
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
      results = {target_nodes.name.to_sym => Thread.current['results']}
      
      @tasks_mutex.synchronize {
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
      if not task.sync then ## task has to be treated before run it
        # puts "Task has to be thread before run it"
        # Two cases, asynchronously task or job asynchronously
     
        if task.job_async? and not job.nil? then   ## This tasks can be splitted several times
          puts "creating a new task for the job"
          ## we have to create a new task for that particular job
          root_task = task.split(job.to_s)
          puts "task : #{root_task.name} created"
          new_tasks.push(root_task)
          tasks_changed = true
      
        elsif not task.split? 
          ## if the task haven been split
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
   
    task_scheduled = false
  
    ## We can proceed to execute the tasks 
    @tasks.each{ |task|
      #puts "Trying to schedule task: #{task.name}"      
      if task.sync and  not @registry.has_key?(task.name) then ## the task is executable and has not been executed 
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
    puts "No task schedule" if not task_scheduled
            
    # while execute_task do

    #   ## if there are not more task to execute we exited
    #   if not_pending? then
    #     puts "All task have been executed"
    #   elsif
    #   if @tasks.length == 0 then
    #     puts "All task have been executed"
    #     execute_task = false
    #   elsif @tasks.first.dependency.nil? then
    #     current_task = @tasks.shift
    #     puts "Scheduling new task"
    #     execute_task(current_task)
    #   elsif check_dependency?(@tasks.first) then
    #     current_task = @tasks.shift
    #     puts "Scheduling new task"
    #     execute_task(current_task)
    #   else
    #     execute_task = false
    #   end
    # end 
      
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
