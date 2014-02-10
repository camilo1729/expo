## This class will register the task defined in the experiment.
## This class will send notiifications to the class Taskmanager using notifications

require 'rubygems'
require 'observer'
require 'thread'

class Task
  
  include Observable
  attr_accessor :name, :options, :dependency, :target, :async, :cloned_from, :executable, :resource, :cloned
  attr_reader :exec_part, :children, :job_async, :sync, :start_time, :end_time
  
  
  def initialize(name, options ={}, &block)
    @name, @options = name, options
    @options[:parallel] = false if options[:parallel].nil?
    @exec_part = block or raise ArgumentError, "a task definition requires a block"
    @dependency = options[:depends] || [] ## Array of dependencies
    @timeout = 3600  if options[:timeout].nil?
    @timeout = options[:timeout] unless options[:timeout].nil?
    ## job synchrony
    # @job_async = options[:job_async].nil? ? false : true  
    ## Type of resource associateted, it could be a node, cluster, site or job
    ## It will use this information to divide task and take the appropiate resources
    @resource = options[:res_granularity]
    ## This target will be used by execute in order to know where to execute
    @target = nil
    ### task that have this property setted to true will be executed otherwhise
    ### They have to be split 
    @async = (options[:async].nil? or options[:sync].nil?) ? false : true
    @sync = (options[:sync].nil? or options[:async].nil?) ? false : true
    @cloned = false
    @update_mutex = nil #Mutex.new
    @cloned_from = nil
    @children = []
    @executable = options[:res_granularity].nil? ? true : false #it is executable when the task is synchronous from the begining
    @start_time = nil
    @end_time = nil
  end

  def run()
    ## I have to improve this mechanism to manage different messages
    @start_time = Time.now
    @exec_part.call
    @end_time = Time.now
    @update_mutex.synchronize {
      changed   ## this has to be thread safe 
      notify_observers(self)
    }
  end

  def run_time
    @end_time.to_f - @start_time.to_f
  end

  def warning
    puts "Task #{id} has reached timeout be carefull"
    puts "Finish task"
  end

  def set_taskmanager( task_manager )
    @task_manager = task_manager
    add_observer(task_manager)
    ## we set the mutex as well
    @update_mutex = task_manager.notification_mutex
  end

  def job_async?
    return @job_async
  end

  def cloned?
    return @cloned
  end

  def clone()
    ## We have to do a deep copy for the options array
    # copy_options = deep_copy(self.options)
    ## This is in order to not dump the resource set when it has a file for resource set
    copy_options = deep_copy(self.options.reject{ |key,value| key == :target})
    # The following has to be done in order to not lose the
    # reference of the resources, because it can be updated asynchronously
    copy_options[:target] = self.options[:target] 
    Task.new(self.name, copy_options, &self.exec_part)
    
  end

  ## Deep copy implementation
  def deep_copy(o)
    Marshal.load(Marshal.dump(o))
  end

  def clone_with_criteria(criteria)
    ## Job number
    ## site array
    ## cluster array
    ## node array
    if criteria.is_a?(String) then ## we received a job number
      task_j = self.clone
      task_j.name = (self.name.to_s+"_"+criteria.to_s).to_sym
      task_j.cloned_from = self.name
      task_j.target = criteria ## as a number, execute will know that it is a job so it has to select resources by Id
      task_j.async = false ## the task cannot be asynchronic anymore inside itself
      task_j.resource = nil
      task_j.executable = true
      self.executable = false # The current task cannot be executed anymore
      @cloned = true ## in order to not clone it again
      @children.push(task_j.name)
      return task_j

    elsif criteria.is_a?(Hash) then ## we received a resourceset
      ##  { :type => [array_ids] }
      ##  { :cluster => [adonis, genepi] }

      task_set = []
      criteria.each{ |key, values|
        values.each{ |id|
          task_r = self.clone
          task_r.name = (self.name.to_s+"_"+id.to_s).to_sym
          task_r.cloned_from = self.name
          task_r.target = id
          task_r.executable = true
          task_r.async = false
          task_r.cloned = true  ### I have to check this part probably is not the way to do it.
          @children.push(task_r.name)
          task_set.push(task_r)
        }
      }
      @cloned = true
      self.executable = false
      return task_set
    end
    
  end


end
