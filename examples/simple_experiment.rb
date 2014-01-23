### Simple experiment To test

require 'g5k_api'

set :user, "cruizsanabria" 
set :resources, "MyExperiment.resources"
# set :gateway, "grenoble.g5k" #Only if you execute the script outside Grid5000

reserv = connection(:type => "Grid5000")
reserv.resources = {:lyon => ["nodes=1"]}

## We grab a job that was already created by the user manually
## In order to use this functionality I have to submit the job with -t allow_classic_ssh 

task_definition_start

# set_experiment_variables


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

task :task_3, :target => resources.first do
  run("sleep 5")
  run("uname -a")
end

task :testing_resourceset do
  resources.each{ |node|
    run("sleep 20",:target => node)
  }
end

# task :free_reservation, :target => resources do
#   free_resources(reserv)
# end


