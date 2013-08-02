require 'expo'
require 'g5k_api'

task :reservation do
  reserv = ExpoEngine.new()
  reserv.site=["bordeaux","sophia","grenoble","nancy","lille","rennes"]
  reserv.environment="squeeze-x64-big"
  reserv.resources=["nodes=1"]
  reserv.run!
end





set :user, "cruizsanabria"

## here it is not that easy
## as singlenton we have

## all variables are stored in @variables.
Experiment.instance.resources


set :resource_set, Experiment.resources
set :flat_resources, Experiment.resources.nodefile

set :server, Experiment.resources[1]





task :resourceset_command, :target => :resource_set do
  chef("apache")

  run("hostname")
end



task :install_server, :taget => 

task :flat_resources, :target => :flat_resources do
  run("hostname")
end


### integration with Chef
master = resource_set.shift
clients = resource_set

set :cookbook_path, "/home/cristian/Dev/Chef"

task :provision_master, :target => master do
  add_recipe("dns")
  add_recipe("apache")
end

task :provision_clients, :target => clients do
  add_recipe("openssl")
end

## Iterating over the resources

task :iteration do
  sizes = [50,100,150,200,250,300]

  Experiment.resources.each_slice_array(sizes) do |nodes|
    task :iterate, :target => nodes, :repeat => 10 do
      run("hostname")
    end
  end
  
end

clients = Experiment.resources[1..100]



ruby_task :test, :target => Experiment.resources do
  system("hostname")
  File.open("/root/results.txt",'w'){ |f| f.write "test"}
end
    
