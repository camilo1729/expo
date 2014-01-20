### Simple experiment To test

require 'DSL'
require 'g5k_api'

set :user, "cruizsanabria"

reserv = ExpoEngine.new("grenoble.g5k")
resources = MyExperiment.resources

## We grab a job that was already created by the user manually
reserv.jobs_id = {:lyon => 688461}
## In order to use this functionality I have to submit the job with
# -t allow_classic_ssh 

reserv.resources = {  :lyon => ["nodes=1"] }
reserv.wait = true


### Tasks definition

task :run_reservation do
  reserv.run!
end

task :task_1, :target => resources do
  run("hostname")
end

task :task_2, :target => resources do
  run("sleep 10")
  run("hostname")
end

task :task_3, :target => resources do
  run("sleep 5")
  run("uname -a")
end

start_experiment
