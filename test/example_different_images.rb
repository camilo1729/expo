
## Some variables
set :master_image => "http://public.grenoble.grid5000.fr/~cruizsanabria/master.env"
set :client_image => "http://public.grenoble.grid5000.fr/~cruizsanabria/client.env"
set :user, "cruizsanabria"

## Reservation part
reserv=ExpEngine.new()
reserv.site=["bordeaux","sophia","grenoble"]
reserv.environment = {:master_image => 1,:client_image=>10}
reserv.walltime = 3600
reserv.run!


master= Experiment.resources[:image => "master_image"]
clients = Experiment.resources[:image => "client_image"]


#### Postinstallation part 

task :post_install_master, :target => master do
  run_recipe("dns")
end

task :post_install_client, :target => clients do
  run_recipe("open_ssh")
end

####
