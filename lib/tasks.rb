## This class will register the task defined in the experiment.
## This class will send notiifications to the class Taskmanager using notifications
## form the celluloid library

require 'rubygems'
#require 'celluloid/autostart'
require 'observer'
require 'thread'

class Task
  
  include Observable
  attr_accessor :name, :options, :dependency, :target, :split, :sync, :split_from
  attr_reader :exec_part, :sync, :children, :resource, :job_async
  
  
  def initialize(name, options ={}, &block)
    @name, @options = name, options
    @exec_part = block or raise ArgumentError, "a task definition requires a block"
    @dependency = options[:depends]
    @timeout = 3600  if options[:timeout].nil?
    @timeout = options[:timeout] if not options[:timeout].nil?
    ## job synchrony
    @job_async = options[:job_async].nil? ? false : true  
    ## Type of resource associateted, it could be a node, cluster, site or job
    ## It will use this information to divide task and take the appropiate resources
    @resource = options[:type]
    ## This target will be used by execute in order to know where to execute
    @target = nil
    ### task that have this property setted to true will be executed otherwhise
    ### They have to be split 
    @sync = (options[:async].nil? and options[:job_async].nil?) ? true: false
    @split = false
    @update_mutex = nil #Mutex.new
    @split_from = nil
    @children = []
  end

  def run()
    ## I have to improve this mechanism to manage different messages
    @exec_part.call
    @update_mutex.synchronize {
      changed   ## this has to be thread safe 
      notify_observers(self)
    }
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

  def split?
    return @split
  end

  def clone()
    ## We have to do a deep copy for the options array
    # copy_options = deep_copy(self.options)
    copy_options = deep_copy(self.options)
    # The following has to be done in order to not lose the
    # reference of the resources, because it can be updated asynchronously
    copy_options[:target] = self.options[:target] 
    Task.new(self.name, copy_options, &self.exec_part)
    
  end

  ## Deep copy implementation
  def deep_copy(o)
    Marshal.load(Marshal.dump(o))
  end

  def split(criteria)
    ## Job number
    ## site array
    ## cluster array
    ## node array
    if criteria.is_a?(String) then ## we received a job number
      task_j = self.clone
      task_j.name = (self.name.to_s+"_"+criteria.to_s).to_sym
      task_j.split_from = self.name
      task_j.target = criteria ## as a number, execute will know that it is a job so it has to select resources by Id
      task_j.sync = true ## we make it runnable
      self.split = true ## in order to not split it again
      self.sync = false  ## This task can not be executed anymore
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
          task_r.split_from = self.name
          task_r.target = id
          task_r.sync = true
          @children.push(task_r.name)
          task_set.push(task_r)
        }
      }
      self.split = true
      self.sync = false
      return task_set
    end
    
  end


end
