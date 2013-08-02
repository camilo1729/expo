# -*- coding: undecided -*-
require './expectrl'
require './DSL'
require './g5k_api'



reserv=ExpoEngine.new()
# $reserv.site=["bordeaux","toulouse","luxembourg","sophia","grenoble","nancy"]
reserv.site=["bordeaux","sophia","grenoble","nancy","lille","rennes"]
# $reserv.site=["bordeaux"]
# $reserv.resources=["nodes=35","nodes=30","nodes=15","nodes=20","nodes=10","nodes=10"]
# $reserv.site=["bordeaux"]
reserv.environment="squeeze-x64-big"
reserv.resources=["nodes=1"]
reserv.run!


resource_set = Experiment.instance.resources
flat_resources = Experiment.instance.resources.nodefile

#roles :flat_set, Experiment.instance.resources.nodefile

set :user, "cruizsanabria"

tmp = {}

task :resouceset_command, :target => resource_set do
  tmp = run("hostname")
end

tmp[:run_time]

tmp2 = {}

task :flatset_command, :target => flat_resources, :repeat => 10  do
  tmp2 = run("hostname")
end


task :flatset_commnad, :repeat => 10

tmp2[:run_time]


### Chef recipes

### assign the first of the resource set and changes the resource set
### It behaves the same as normal arrays in Ruby 
master = resource_set.shift 
clients = resource_set


task :provision_master, :target => master do
  add_recipe("dns")
  add_recipe("apache")
end

task :provision_clients, :target => clients do
  add_recipe("open_ssl")
end



# all_nodes=Experiment.instance.resources

# all_nodes.each_slice_array(sizes) do |nodes|

#   (10).times{
#     task :iterate, :hosts => nodes do
#       run_remote("hostname")
#     end
#   }
# end


task :test_deploy, :target=> Experiment.instance.resources do
  run("gem install pry")
end


task :test_deploy, :repeat => 10 




### I have to create a machanism to get the information of the platform and
### hardware used for a particular experiment.

## Track back the hardware used

## capistrano manage of environment variables

# set :default_environment, {

#   ‘PATH’ => ‘/var/lib/gems/1.9.1/bin:/usr/local/bin:/usr/bin:/bin’,

#   ‘TERM’ => ‘dumb’,

# }

# rollback when there is an error propose a procedure to follow.

# on_rollback { find_and_execute_task("deploy:stop") }
# on_rollback { run "rm #{deploy_to}/shared/system/maintenance.html" }


