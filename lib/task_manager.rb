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

  def initialize(object=nil)
    @object = object
  end
end


require 'pry'

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

    @logger = Log4r::Logger['Expo_log']

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
    ## if the task already exist or have been executed
    ## We dont include it
    return false unless get_task(task.name).nil?
    return false if @registry.has_key?(task.name)
    task.set_taskmanager(self)
    @logger.info "Registering Task: "+ "[ #{task.name} ]"
    @tasks.push( task )
    ## creating the respective hash for results of that task
    MyExperiment.results_raw[task.name.to_sym] = [] if task.cloned_from.nil?
    ## just for tasks that have not been cloned
  end

  def add_tasks(tasks)
    tasks.each{ |t|
      self.push(t)
    }
  end


### Executes a Task
  def execute_task(task)

    @logger.info "Executing Task: "+ "[ #{task.name} ]"

    options = task.options

    task_resources = options[:target]

    resources_info = []
    # Dealing with lazy evaluation
    # options[:taget] will be an array [var,operator]
    if options[:lazy] then
      var = options[:target][0]
      # we evaluate just the variable and then the operator
      task_resources = eval("#{var}",MyExperiment.variable_binding)
    end

    if task_resources.nil? then
      # We are executing in localhost
      resources_info = ["localhost"]

    elsif task.target.nil? then
      target_resources = task_resources
      resources_info = task_resources

    elsif task.target.is_a?(String) then
      if task.target.is_integer? then
        job_id = task.target
        @logger.info "Clonnig Task for the Job: " + "#{job_id}"
        target_resources = task_resources.select(:id => job_id.to_i )
        resources_info = task_resources.select_resource_h(:id => job_id.to_i)
      else
        resource_name = task.target
        target_resources = task_resources.select(:name => resource_name)
        resources_info = task_resources.select_resource_h(:name => resource_name)
      end
    end

    if options[:lazy] then
      operator = options[:target][1]
      # we evaluate now the operator
      target_resources = eval("target_resources.#{operator}")
    end

    if options[:once] then
      target_resources = target_resources.first if target_resources.is_a?(ResourceSet)
      @logger.info "Executing just on the first node"
    end

    @logger.info "Executing task on: #{resources_info}"

    Thread.new {
      Thread.abort_on_exception=true
      begin
        Thread.current['results'] = []
        Thread.current['resources'] = target_resources #unless target_resources.nil?
        Thread.current['task_options'] = options
        Thread.current['info_resources'] = resources_info unless target_resources.nil?
        ## to avoid concurrency between tasks
        sleep(rand(20)/7.to_f)
        task.run
        exception = false
      rescue ExecutingError => e
        @logger.error "Task: #{task.name} =>"+" Failed"
        @logger.error "error: #{e.object}"
        task_name = task.cloned_from.nil? ? task.name : task.cloned_from
        results = e.object
        MyExperiment.results_raw[task_name.to_sym]=results  ## I have to merge here
        @registry[task.name] = "Failed"
        exception = true
        binding.pry # We provide access to the interactive console
      end


      unless exception then
        unless target_resources.is_a?(String) then
          @tasks_mutex.synchronize {

            ## Get the name of the task
            ## if the task has been cloned we get the name of the father
            task_name = task.cloned_from.nil? ? task.name : task.cloned_from
            MyExperiment.results_raw[task_name.to_sym]+= Thread.current['results'] ## this is an array
          }
        end
      end
    }
    @registry[task.name] ="Running"
  end


  def updating_dependencies()
    ## This function will update dependencies for every task
    ## And will create the neccesary new tasks
    @logger.info "Updating dependencies....."
    new_tasks_dep = []
    @tasks.each{ |task|
      ## we loop into the dependencies
      unless task.sync then  ## unless the task is synchronous otherwise we have to update the task
        if check_dependency_change?(task) then
          task.dependency.each{ |t_name|

            task_depen = get_task(t_name)
            task_depen.children.each{ |c_t|
              suffix = c_t.to_s
              suffix.slice!(task_depen.name.to_s+"_")
              if not task.children.include?((task.name.to_s+"_"+suffix).to_sym) then
                n_t = task.clone_with_criteria(suffix)
                #puts "Task : " + "[#{n_t.name}] ".green + " created for dependency"
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

    ## First thing to do we get the task from the experiment
    if @task_from_experiment
      @logger.info "Getting tasks from Experiment"
      tasks_expe = MyExperiment.get_available_tasks
      add_tasks(tasks_expe) unless tasks_expe.nil?
    end

    new_tasks = []

    ## First we have to analyze the tasks
    tasks_changed = false

    @tasks.each{ |task|


      ## is the task ready to run?
      unless task.resource.nil? then ## task has to be treated before run it

        # we verify first if the task is ready to run
        if check_dependency?(task) then
        # Two cases, asynchronously task or job asynchronously
          @logger.debug "Checking task : #{task.name}"
          if task.resource == :job
            unless job.nil?
              # we have received a job as a parameter for scheduler
              #  if task.job_async? and not job.nil? then
              ## This tasks can be splitted several time
              @logger.info "Creating a new task for the job"
              ## we have to create a new task for that particular job
              root_task = task.clone_with_criteria(job.to_s)
              @logger.info "Task : "+"[#{root_task.name}] created"
              new_tasks.push(root_task)
              tasks_changed = true
            end

          elsif not task.cloned?
            ## If the task has not been cloned
            ## We clone according to the resources established in the resource of the task
            clone_hash = { task.resource => [] }
            task_resources = task.options[:target]
            task_resources.each(task.resource){ | res |
              clone_hash[task.resource].push(res.name)
            }
            new_tasks = task.clone_with_criteria(clone_hash) ## This return an array

            tasks_changed = true
          end
        end
      end
    }

    ## we add the new tasks to the @task variable
    add_tasks(new_tasks)
    ## update the dependencies if it is necessary
    ## check if a the children of a asynchronous task have finished

    updating_dependencies if tasks_changed

    task_scheduled = false

    check_asynchronous_termination

    # in order to do synchronizations this has to be here in order to trigger the next task

    ## We can proceed to execute the tasks
    @tasks.each{ |task|

      @logger.debug "Looking task : #{task.name} is executable #{task.executable}"
      if task.executable and  not @registry.has_key?(task.name) then
        ## the task is executable and has not been executed
        @logger.debug "Task #{task.name} is executable"
        if check_dependency?(task) then
          execute_task(task)
        end
        task_scheduled = true
      end

    }



    unless task_scheduled
      @logger.info "No task to schedule"
      @no_tasks = true
    end

  end

  def check_asynchronous_termination
    @tasks.each{ |task|
      ## Two cases job synchronous
      ## we have to consult the experiment information
      ## in order to know if all the children have finished
      if task.cloned? and not @registry.has_key?(task.name) then
        ## the task has been cloned and it does not exist in the registry
        children_finished = 0
        task.children.each{ |ch_name|
          children_finished += 1 if @registry[ch_name] == "Finished"
        }
        if task.resource == :job
          @registry[task.name]= "Finished" if children_finished == MyExperiment.num_jobs_required
        else
          if task.cloned_from.nil? then
            if check_dependency?(task) && (children_finished == task.children.length) then
              @logger.debug "Finish task : #{task.name}"
              @registry[task.name] = "Finished"
              # We call the scheduler again
              #schedule_new_task
            end
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
      d_t = get_task(d_name)
      return true if d_t.cloned?
    }
    return false
  end

  def check_dependency?(task)
    # puts "Checking dependency of task #{task.name}"
    return true if task.dependency.nil?
    task.dependency.each{ |d|
      return false if @registry[d] != "Finished"
    }
    return true
  end

  def delete_task(task_name)
    @tasks.delete_if{ |t| t.name == task_name }
  end

  ## This function returns the tasks that depends on a given task
  def update(task)
    task_name = task.name
    @logger.info "Task: "+ "#{task_name}\t" + "[ DONE ]" + " In #{task.run_time.round(3)} Seconds"
    sleep(rand(10)/17.to_f)
    @registry[task_name] = "Finished"
    schedule_new_task
  end

end
