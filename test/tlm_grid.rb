require 'expo'
require 'g5k_api'

task :reservation do
  reserv = ExpoEngine.new()
  reserv.site = ["nancy","rennes","lille","grenoble","sophia"]
  reserv.resources = ["nodes=1"]
  reserv.name = "Tlm Code"
  reserv.walltime = 2000
  reserv.environment = "http://public.grenoble.grid5000.fr/~cruizsanabria/tlm_simulation.env"
  reserv.run!
end

set :user, "cruizsanabria"
set :result, nil

task :setting_up do
  Experiment.resources.gen_keys
  put Experiment.resources.nodefile, :target => Experiment.resources.first, :path => "/root/nodes.deployed"
end

task :tlm_grid, :target => Experiment.resources.first do
  result = run("/root/lancergrid 1 3869 192 561 25 1 s c") 
end

task :stop do
  reserv.stop!
end
