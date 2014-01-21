### Simple experiment To test

require 'g5k_api'

set :user, "cruizsanabria"
set :resources, "MyExperiment.resources"

reserv = ExpoEngine.new("grenoble.g5k")
reserv.jobs_id = {:lyon => 688874}
reserv.resources = {:lyon => ["nodes=1"]}
reserv.wait = true

## We grab a job that was already created by the user manually
## In order to use this functionality I have to submit the job with -t allow_classic_ssh 

task_definition_start

# set_experiment_variables

task :run_reservation do
  reserv.run!
end

task :task_1, :target => "resources" do
  run("hostname")
end

task :task_2, :target => "resources" do
  run("sleep 10")
  run("hostname")
end

task :task_3, :target => "resources.first" do
  run("sleep 5")
  run("uname -a")
end

task :testing_resourceset do
  resources.each{ |node|
    run("sleep 100",:target => node)
  }
end

start_experiment


