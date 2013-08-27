## This is the first version of task Scheduler
## Thiis task scheduler uses the actor model provided by Celluloid
#require 'expectrl'
require 'rubygems'
require 'observer'


class TaskManager

  #MyExperiment = Experiment.instance
  # include Observable
  ## This class will be notified from the DSL execute 
  def initialize( tasks = nil )  #tasks )
    @tasks = tasks.nil? ? [] : tasks
    @registry = {}
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
    task.set_taskmanager(self)
    @tasks.push( task )
  end

  def add_tasks( tasks )
    tasks.each{ |t|
      self.push(t)
    }
  end


  def execute_task( task)
    puts "Executing task #{task.name}"
    sleep 0.5
    Thread.new {
      task.run
    }
  end

  def schedule_new_task(job=nil)
    ## while first task in the task array can be executed
    execute_task = true
    ## first thing to do we get the task from the experiment
    task_temp =   MyExperiment.get_task if @task_from_experiment ## Get a new task from the experiment if that is the case
    self.push( task_temp ) if not task_temp.nil? ## we put it into the internal array

    ## This function will possibly be call by several threads so it has to be thread safe :D
    ## I think we have to assure this in the g5k api code
    new_tasks = []
    ## First we have to analyze the tasks
    @tasks.each{ |task|
      ## is the task ready to run?
      if not task.sync then ## task has to be treated before run it
        puts "Task has to be thread before run it"
        ## Two cases, asynchronously task or job asynchronously
        new_tasks = []
        if task.job_async? and not job.nil? then
          puts "creating a new task for the job"
          ## we have to create a new task for that particular job
          root_task = task.split(job)
          new_tasks.push(root_task)
          ## we have to split as well all the task that depends on it
          d_tasks = uppper_depends( task.name )
          
          d_tasks.each{ |d_t|
            ## we delete the dependency
            n_t = d_t.split(job)
            n_t.dependency.delete( task.name )
            n_t.dependency.push( root_task.name )
            new_tasks.push(n_t)
          }
        elsif not task.split? ## if the task haven been split
          ## We split according to the resources established in the resource of the task
          split_hash = { task.resource => [] }
          MyExperiment.resources.each(task.resource){ | res |
            split_hash[task.resource].push(res.name)
          }
          root_tasks = task.split(split_hash) ## This return an array
          new_tasks += root_tasks

          d_tasks = uppper_depends( task.name )
          
          d_tasks.each{ |d_t|
            ## we delete the dependency
            n_t = d_t.split(split_hash) ## This return an array
            n_t.each_with_index{ | t, i|
              t.dependency.delete( tasks.name )
              t.dependency.push( root_task[i].name )
            }
            new_tasks =+ n_t
          }
        end
      end
    }
    ## we add the new tasks to the @task variable
    add_tasks(new_tasks)
    ## We can proceed to execute the tasks 

    task_scheduled = false
    executed_tasks = []
    @tasks.each{ |task|
      puts "Trying to schedule task: #{task.name}"
      if task.sync then ## the task is executable and has not been executed 
        puts "Task #{task.name} is executable"
        if task.dependency.nil? then
          puts "Scheduling new task"
          execute_task(task)
          executed_tasks.push(task.name)
        elsif check_dependency?(task) then
          puts "Scheduling new task after checking dependency"
          execute_task(task)
          executed_tasks.push(task.name)
        end
        task_scheduled = true
      end
    }
    executed_tasks.each{ |t| delete_task(t) }
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

  def check_dependency?( task )
    puts "Checking dependency of task #{task.name}"
    task.dependency.each{ |d|
      return false if not @registry.has_key?(d)
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
    sleep 1
    @registry[task_name] = "OK"
    schedule_new_task
  end
  
end



# load 'task_manager.rb'
# load 'task.rb'
