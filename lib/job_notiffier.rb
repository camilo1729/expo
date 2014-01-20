require 'expectrl'
require 'DSL'

class JobNotifier
  
  MyExperiment = Experiment.instance
  Console = DSL.instance
  def initialize
    @num_jobs = 0  
  end

  def update(job_id,logger)
    ## this part will read the base task in take decisions accordondly
    logger.info "A notification has been triggerd"
    logger.info "From job #{job_id}"

    job_asynchrony = false
    sleep( (rand(10/7.to_f)))

    ## This will look if there is a task declared as job asynchronous
    MyExperiment.tasks.each{ |name, task_obj|
      job_asynchrony = true if task_obj.resource == :job
    }
      
    if job_asynchrony == false then ## we wait everybody to trigger Task execution
      @num_jobs+=1
      if MyExperiment.num_jobs_required == @num_jobs then ## we reached the number of jobs required for the experiment
        logger.info "Executing task: #{MyExperiment.tasks.first[0]}"
        Console.task_manager.schedule_new_task() ## first for a hash returns a vector [key, value]
      end
      
    elsif job_asynchrony == true then ## we start runnig task and we pass the job id to create the respective resource_set
      if job_id == 0 then
        logger.info "There was an error in the Job submition notifying the task manager"
        sleep( (rand(20/7.to_f)))
        Console.task_manager.schedule_new_task()
      else
        Console.task_manager.schedule_new_task(job_id)
      end
    end
  end
end
