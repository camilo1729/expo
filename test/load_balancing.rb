# -*- coding: utf-8 -*-
## This is the file used for experimenting with load balancing

# This is the information to get

# [{"model"=>"Intel Xeon",
#   "clock_speed"=>3000000000,
#   "cache_l1d"=>16384,
#   "version"=>"3.00GHz",
#   "other_description"=>"Intel(R) Xeon(TM) CPU 3.00GHz",
#   "cache_l1"=>nil,
#   "cache_l2"=>1048576,
#   "vendor"=>"Intel",
#   "instruction_set"=>"x86-64",
#   "cache_l3"=>0,
#   "cache_l1i"=>0},


# File.open("results_cpus",'w+') do |file|
#   file.puts("processor\t clock_speed \t cache l1d \t cache l2 \t cache l3")  
#   processors.uniq.each { | proc| 
#     file.puts("#{proc['model']}\t #{proc['smp_size']} \t #{proc['clock_speed']}\t#{proc['cache_l1d']} \t #{proc['cache_l2']} \t #{proc['cache_l3']}\t #{proc['site']} \t #{proc['cluster']}")    
#   }  
# end  


require 'g5k_api'
require 'expo'
# This is the point of contact with the API
reserv = ExpoEngine.new

processors = reserv.get_processors

sites = []
cluster = []

## Getting the different sites and cluster in order to make the reservation.
processors.each { |proc| 
  sites.push(proc['site'])
  cluster.push(proc['cluster'])
}

## In theory sites and cluster are written in the same order.
cluster.each{ |c|
  ## putting the cluster names in the reservation
  reserv.resources.push("#{c}/nodes=1")
}

## putting the sites names in the reservation.
reserv.site = sites.uniq

reserv.run!


set :user, "cruizsanabria"





## Today I implemented the function for putting files into the nodes.
## And a way to check if the files or commands are available on the nodes

## I had to do the following in order to interact with the virtual infrastructure.
resources = YAML::load(File.read('nodes_test.res'))


## Example the put function

task :copy_test, :target => resources do 
  put("hola.txt", "/root/", :method => "scp")
end

## checking if a determined file exist in a node

task :check, :target => resources do 
  run("ls /root/hola.txt")
end

## here the task function will return the number of succesful commands executed.



task :tlm, :target => Experiment.instance.resources do 
  run("")
end


## Second Day, Experiment 


require 'DSL'

set :user, "root"

## Loading the virtual resources from a file.

resources = YAML::load(File.read('nodes_test.res'))

## Checking the presence of mpirun

## Check first if all the machine are responding

task :check_machines, :target => resources do 
  run("hostname")
end


k = TakTuk::Aggregator.new([:host,:pid,:start_date,:stop_date])

if res[:results][:status].aggregate(k).values.length == 1 then
  if res[:results][:status].aggregate(k).values.first[:line] == "0" then
    puts "All the machines are OK"
  end
end

task :check_mpi, :target => resources do
  run("which mpirun")
end


task :copy_tlm, :target => resources do 
  put("/home/cristian/Dev/C++/TLM_2013/tlm_clean_version.tar","/root/",:method => "scp")
end

Experiment.instance.show_commands

task :check_tlm, :target => resources do 
  run("ls /root/tlm.tar")
end

## To examine results

k = TakTuk::DefaultAggregator.new

## errors
res[:results][:error].aggregate(k).values.first[:line]

## output
res[:results][:output].aggregate(k).values.first[:line]


task :extract_code, :target => resources do 
  run("tar -xvf /root/tlm.tar")
end

task :check_code, :target => resources do 
  run("ls /root/TLMME_Cristian")
end

task :compile_code, :target => resources do 
  run("make -C /root/TLMME_Cristian/tlm/")  ## I need mpiiiii 
end

task :check_bin, :target => resources do 
  run("ls /root/TLMME_Cristian/tlm/bin/tlm")
end


task :execute_code, :target => resources do
  run("cd ~/TLMME_Cristian/tlm/;./run 1 4000 25 100 50 matched")  
end  

task :execute_code, :target => resources do
  run("cd ~/TLMME_Cristian/tlm/;./run 1 10000 25 86 43 matched")  
end  






### To manage the results,
## Time for each running process.
k = TakTuk::Aggregator.new([:host,:pid,:command,:line])

res[:results][:status].aggregate(k).values.each{ |k|
  puts "time: #{k[:stop_date].to_f - k[:start_date].to_f}"  
}


## Another way
res[:results][:status].compact!.each{ |k|
  puts "#{k[:host]} time #{k[:stop_date].to_f-k[:start_date].to_f}"  
}


## Execution in Grid5000

task :create_tmp_dir, :target => Experiment.instance.resources do
  run("mkdir /tmp/tlm/")
end  



### I have a problem with the execution in Grid5000
### cmdctrl it doesn work
### The problem is due to Ruby version, Grid5000 1.8.7 my laptop 1.9.3


## Now I started to execute everything from my machine, in order to better control the ruby versions

# I will use the SSH class in order to perform the remote execution

# I modify the resource set to put a gateway for all the resources which will be my local machine

## comunication with the api from the outside are done with the folling file:


# username: USER_NAME
# password: GRID5000PASSWORD
# base_uri: https://api.grid5000.fr/2.0/grid5000

require 'g5k_api'
require 'DSL'

reserv = ExpoEngine::new("grenoble.g5k") ## chossing a gateway for connecting to the infrastructure

reserv.resources = ["nodes=1","nodes=1"]
reserv.site = ["grenoble","toulouse"]

reserv.run!

resources = Experiment.instance.resources

task :test, :target => resources do 
  run("hostname")
end



# This example works without error from my local machine


## Transfering file from the local machine to the gateway machine


task :transfering_gw, :target => resources.gw do
  put("/tmp/file.txt","/tmp/file2.txt",:method => "scp")
end


### From gateway machine to the other machines
task :tranfert, :target => resources do 
  put("/tmp/hola.txt","/tmp/hola2.txt",:method=>"scp")
end


## Forth day, First experiment for calibration
## Description file

require 'g5k_api'
require 'DSL'

set :user, "cruizsanabria"
set :gateway, "grenoble.g5k"

reserv = ExpoEngine::new("grenoble.g5k")

processors = reserv.get_processors

sites = []
cluster = []

## Getting the different sites and cluster in order to make the reservation.
## reinitializing reserv
reserv.site = []
reserv.resources = []

## creating a reservation for each cluster contain in the structure processors
processors.each { |site|
  reserv.site.push(site[:site])
  temp_str = ""
  site[:clusters].each_with_index{ |cluster,index|
    cluster_name = cluster["cluster"]
    temp_str += "cluster='#{cluster_name}' "
    temp_str += "or " unless index == site[:clusters].length - 1
  }
  final_str = "{#{temp_str}}/cluster=#{site[:clusters].length}/nodes=3"
  reserv.resources.push(final_str)
}

## The problem with this reservation is that 
# there is a big heterogenity between clusters of the same site 
# Therefore is better to submit jobs per cluster, 
# in order to free resources.
processors.each { |site|
  temp_str = ""
  site[:clusters].each_with_index{ |cluster,index|
    reserv.site.push(site[:site])
    cluster_name = cluster["cluster"]
    submit_line = "{cluster='#{cluster_name}'}/nodes=3"
    reserv.resources.push(submit_line)
  }
}





# ## putting the sites names in the reservation.
# reserv.site = sites

reserv.run!
## Transfering tlm archive from the local machine ot the gateway machine

task :transfering_gw, :target => resources.gw do ## There is a bug hwne the variable gateway is already defined
  put("/home/cristian/Dev/C++/TLM_2013/tlm_clean_version.tar","/tmp/tlm_test.tar",:method => "scp")
end

## transfering to each site

resources.each(:resource_set){ |site|

  task :transfering_site, :target => site.gw, :gateway => "grenoble.g5k" do
    run("mkdir ~/tmp_tlm/")
    put("/tmp/tlm_test.tar","/home/cruizsanabria/tmp_tlm/tlm_test.tar",:method => "scp")   
  end
}


task :check_tlm, :target => resources do 
  run("ls ~/tmp_tlm/tlm_test.tar")
end

## To examine results

k = TakTuk::DefaultAggregator.new

## errors
res[:results][:error].aggregate(k).values.first[:line]

## output
res[:results][:output].aggregate(k).values.first[:line]


resources.each(:resource_set){ |site|
  task :extract_code, :target => site.gw, :gateway => "grenoble.g5k" do 
    run("cd ~/tmp_tlm/; tar -xvf tlm_test.tar")
  end
}   ## probably I have to optimize this loop with taktuk

task :check_code, :target => resources do 
  run("ls ~/tmp_tlm/TLMME_Cristian")
end

k = TakTuk::Aggregator.new([:host,:pid,:start_date,:stop_date])

if res[:results][:status].aggregate(k).values.length == 1 then
  if res[:results][:status].aggregate(k).values.first[:line] == "0" then
    puts "All the machines are OK"
  end
end

## as There is a NFS per site we need to compile the code for just one node on the site.

## second alternative after changing the way resourceset is constructed
resources.each(:resource_set) { |site|
  task :clean_code, :target => site.first.name, :gateway => "grenoble.g5k" do
  run("make -C ~/tmp_tlm/TLMME_Cristian/tlm/")  ## I need mpiiiii 
  end
}   


## This is the old way to do it , now it has changed.
# sites.uniq.each{ |site|
#   node = resources.select_resource(:site => site).first
#   next if node.name=="ExpoEngine" 
#   puts node.name
#   task :compile_code, :target => node.name, :gateway => "grenoble.g5k" do
#     run("make -C ~/tmp_tlm/TLMME_Cristian/tlm/")  ## I need mpiiiii 
#   end
# }


task :check_bin, :target => resources do 
  run("ls ~/tmp_tlm/TLMME_Cristian/tlm/bin/tlm")
end



### Fifth day some results


task :execute_code, :target => resources do
  run("cd ~/tmp_tlm/TLMME_Cristian/tlm/;./run 1 1000 52 240 70 matched")    
end

## results from some clusters
# chimint-9.lille.grid5000.fr time 0.06571006774902344
# parapide-9.rennes.grid5000.fr time 31.20282006263733
# taurus-4.lyon.grid5000.fr time 37.59619998931885
# orion-4.lyon.grid5000.fr time 37.75490999221802
# adonis-9.grenoble.grid5000.fr time 38.91754984855652
# edel-72.grenoble.grid5000.fr time 39.045130014419556
# graphene-26.nancy.grid5000.fr time 39.19777989387512
# chirloute-8.lille.grid5000.fr time 39.515779972076416
# suno-28.sophia.grid5000.fr time 40.735129833221436
# hercule-3.lyon.grid5000.fr time 41.88409996032715
# chinqchint-45.lille.grid5000.fr time 73.37421011924744
# griffon-92.nancy.grid5000.fr time 78.22345995903015
# genepi-31.grenoble.grid5000.fr time 81.25484991073608
# parapluie-5.rennes.grid5000.fr time 81.76021003723145
# paradent-9.rennes.grid5000.fr time 86.9075698852539
# granduc-5.luxembourg.grid5000.fr time 97.30480003356934
# pastel-95.toulouse.grid5000.fr time 120.62723994255066
# helios-9.sophia.grid5000.fr time 149.0249900817871
# sagittaire-9.lyon.grid5000.fr time 328.9635899066925
  

task :execute_code, :target => resources do
  run("cd ~/tmp_tlm/TLMME_Cristian/tlm/;./run 1 10000 52 240 70 matched")  
end  

## To read the time it took
## I have to create some structures for the results

## time_results

## {:name => [] ## results}

results_sim = {}
resources.each{ |node|
  results_sim[node.name.to_sym] = []
}

res = results
res[:results][:status].compact!.each{ |k|
  puts "#{k[:host]} time #{k[:stop_date].to_f-k[:start_date].to_f}"  
  results_sim[k[:host].to_sym].push(k[:stop_date].to_f -k [:start_date].to_f)
}

## Test with less time



task :execute_code, :target => resources do
  run("cd ~/tmp_tlm/TLMME_Cristian/tlm/;./run 1 100 52 240 70 matched")  
end  

task :execute_code, :target => resources do
  run("cd ~/tmp_tlm/TLMME_Cristian/tlm/;./run 1 100 31 305 160 matched ")  
end  




## sith day 

## difine the different parameters to run 

# 1 10000 52 240 70 matched
# 1 2800 47 305 160 matched
# 1 10000 31 305 160 matched
# 1 4000 150 100 50 matched
# 1 10000 38 345 173 matched
# 1 10000 76 86 43 matched
# 1 10000 76 172 86 matched

## I will run those simulations with a time of 100 because given the case I could last 7 hours minimun

# modèle réalisé avec des simulations dont la taille mémoire 2*nx*ny*18*8 dépasse la taille de la mémoire cache, 6MB

# 1 10000 73 400 200 matched
# 1 2800 121 305 160 matched
# 1 9000 2000 80 43 matched
# 1 870 137 317 169 matched
# 1 2817 137 317 169 matched
# 1 6018 500 240 70 matched

params_c1 = [ "100 52 240 70",
           "280 47 305 160",
           "100 31 305 160",
           "400 150 100 50",
           "100 38 345 173",
           "100 76 86 43 ",
           "1000 76 172 86"]

## seventh day

## execution of all combinations
## size smaller than cache size
params_c1 = [ "200 52 240 70",
           "480 47 305 160",
           "200 31 305 160",
           "800 150 100 50",
           "200 38 345 173",
           "200 76 86 43 ",
           "2000 76 172 86"]

temp = params_c1.map{ |k| k.split(" ")[1..k.length]}
size_c1 = temp.map{ |p| p.map!{ |y| y.to_i}.inject(:*) }



results_calibration = {}
resources.each{ |node|
  results_calibration[node.name.to_sym] = []
}


## I have to add something to measure the time for each task
task :calibration, :target => resources do
  params_c1.each{ |par|
    run("cd ~/tmp_tlm/TLMME_Cristian/tlm/;./run 1 #{par} matched")
    puts "Finish parameters #{par}"
    res = results
    res[:results][:status].compact!.each{ |k|
      results_calibration[k[:host].to_sym].push(k[:stop_date].to_f - k[:start_date].to_f)
    }
    puts "#{results_calibration.inspect}"
  }
end
  

## This task took 18 minutes with 
params_c2 = [
             "1000 73 400 200",
             "280 121 305 160",
             "900 2000 80 43",
             "870 137 317 169",
             "281 137 317 169",
             "601 500 240 70"
            ]

sizes_c2 = 
task :calibration, :target => resources do
  params_c2.each{ |par|
    run("cd ~/tmp_tlm/TLMME_Cristian/tlm/;./run 1 #{par} matched")
    puts "Finish parameters #{par}"
    res = results
    res[:results][:status].compact!.each{ |k|
      results_calibration[k[:host].to_sym].push(k[:stop_date].to_f - k[:start_date].to_f)
    }
    puts "#{results_calibration.inspect}"
  }
end


## !! very important all the files have to have the time normalize
File.open("results_calibration_same_time.txt",'w+') do |f|
  f.puts("host param time size")
  results_calibration.each{ |key,value|
    value.each_with_index{ |time,index|
      f.puts("#{key} #{params_c1[index].split(" ").join("-")} #{time} #{size_c1[index]}")
    }
  }
end


## 8th day have to test doubling the parameters

params_c1 = [ "400 52 240 70",
           "1000 47 305 160",
           "400 31 305 160",
           "1600 150 100 50",
           "400 38 345 173",
           "400 76 86 43 ",
           "4000 76 172 86"]

## The task started at 11:44 and ended at 12:27 => 41 minutes  


## I have to test as well what happens if I put the same time to alll the sets of parameters


params_c1 = [ "1000 52 240 70",
           "1000 47 305 160",
           "1000 31 305 160",
           "1000 150 100 50",
           "1000 38 345 173",
           "1000 76 86 43 ",
           "1000 76 172 86"]


## In theory this took 33 minutes

## If I use different times I have to divide by the time


results_temp = []
results_fixed = {}
values.collect{ |p| p.split(" ")[0]}.uniq.each { |u| results_fixed[u.to_sym] = [] }


values.each{ |line|
  temp_host = line.split(" ")[0]
  param = line.split(" ")[1]
  results_fixed[temp_host.to_sym].push(line.split(" ")[2].to_f/(param.split("-").shift.to_f)  )
}  


params_c1 = [ "200 52 240 70",
           "480 47 305 160",
           "200 31 305 160",
           "800 150 100 50",
           "200 38 345 173",
           "200 76 86 43 ",
           "2000 76 172 86"]


temp = params_c1.map{ |k| k.split(" ")[1..k.length]}
size_c1 = temp.map{ |p| p.map!{ |y| y.to_i}.inject(:*) }

file_to_write = "results_calibration_v2_fixed.txt"
File.open(file_to_write,'w+') do |f|
  f.puts("host param time size")
  results_calibration.each{ |key,value|
    value.each_with_index{ |time,index|
      f.puts("#{key} #{params_c2[index].split(" ").join("-")} #{time.to_f/params_c2[index].split(" ")[0].to_f} #{size_c1[index]}")
    }
  }
end


### The previous was to fixed the files generated, we had to divide the time got by the time passed as paramater

## Now I have to try again equal paramaters
## we will assign the lowest time given by mihai which is 2800
params_c1 = [ "2800 52 240 70",
           "2800 47 305 160",
           "2800 31 305 160",
           "2800 150 100 50",
           "2800 38 345 173",
           "2800 76 86 43 ",
           "2800 76 172 86"]



## Now executing the C2 calibration


params_c2 = [
             "200 73 400 200",
             "200 121 305 160",
             "200 2000 80 43",
             "200 137 317 169",
             "200 137 317 169",
             "200 500 240 70"
            ]


## 9th, test with asyncronous tasks


task :test, :target =>resources, :gateway => "grenoble.g5k",:mode => "asynchronous" do
  run("hostname")
end


## Now I will used this parameters to execute the simullations

params_c1 = [ "1000 52 240 70",
           "1000 47 305 160",
           "1000 31 305 160",
           "1000 150 100 50",
           "1000 38 345 173",
           "1000 76 86 43 ",
           "1000 76 172 86"]
temp = params_c1.map{ |k| k.split(" ")[1..k.length]}
size_c1 = temp.map{ |p| p.map!{ |y| y.to_i}.inject(:*) }


## I have to add something to measure the time for each task

set :gateway, "grenoble.g5k"


task :test, :target =>resources,:mode => "asynchronous", :type => :cluster do
  params_c1.each{ |par|
    run("cd ~/tmp_tlm/TLMME_Cristian/tlm/;./run 1 #{par} matched")
    puts "Finish parameters #{par}"
  }
end


results_calibration_file = "results_cal_v6.txt"

File.open(results_calibration_file,'w+') do |f|
  f.puts "cluster params norm_run_time size_struct"
  results_calibration.each{ |key, values|

    cluster = key
    values.each_with_index{ |round,index|
      round[:results][:status].compact!.each { |k|
        run_time = k[:stop_date].to_f - k[:start_date].to_f
        param_round = params_c1[index].split(" ").join("-")
        sim_time = params_c1[index].split(" ")[0].to_f
        norm_run_time = run_time/sim_time
        size_struct = size_c1[index]
        f.puts "#{cluster} #{param_round} #{norm_run_time} #{size_struct}"
      }
    }
  }
end



### day 11

## Test with event job driven 

require 'DSL'
require 'g5k_api'

set :user, "cruizsanabria"
set :gateway, "grenoble.g5k"
reserv = ExpoEngine.new("grenoble.g5k")

res = {
  :grenoble => ["nodes=1"],
  :luxembourg => ["nodes=6"]}
reserv.resources = res

Experiment.instance.base_task = :asynchronous
resources = Experiment.instance.resources

task :init, :target => resources do
  run("hostname")
end


reserv.run!


## Synchronous test are OK
## Asynchronous task OK

## Now testing without the loop ! in G5k module

## It work perfectly , task where executed used job events
# and one was executed 2 minutes after the other :D.


## This is the first try for the callibration


## I have to add something to measure the time for each task

## First Version of the job driven experiment.
require 'DSL'
require 'g5k_api'

set :user, "cruizsanabria"
set :gateway, "grenoble.g5k"
reserv = ExpoEngine.new("grenoble.g5k")

set :gateway, "grenoble.g5k"

### With the new version of resources
res = {}
processors.each { |site|
  temp_str = ""
  res[site[:site].to_sym] = []
  site[:clusters].each_with_index{ |cluster,index|
   
    cluster_name = cluster["cluster"]
    submit_line = "{cluster='#{cluster_name}'}/nodes=3"
    res[site[:site].to_sym].push(submit_line)
  }
}
reserv.resources = res

params_c1 = [ "1000 52 240 70",
           "1000 47 305 160",
           "1000 31 305 160",
           "1000 150 100 50",
           "1000 38 345 173",
           "1000 76 86 43 ",
           "1000 76 172 86"]
temp = params_c1.map{ |k| k.split(" ")[1..k.length]}
size_c1 = temp.map{ |p| p.map!{ |y| y.to_i}.inject(:*) }



task :init, :target =>resources do
  params_c1.each{ |par|
    run("cd ~/tmp_tlm/TLMME_Cristian/tlm/;./run 1 #{par} matched")
    puts "Finish parameters #{par}"
  }
end

reserv.run!

## As the results were putted into arrays , we dont have a hash per cluster
## Then, we are going to create them 

results_calibration = {}

Experiment.instance.results.each{ |cluster|
  node_temp = cluster.first[:results][:status].keys.first[0]
  regexp = /(\w*)-\w*/
  cl = regexp.match(node_temp)
  cluster_name = cl[1]
  results_calibration[cluster_name.to_sym] = []
  cluster.each{ |inv_res|
    results_calibration[cluster_name.to_sym].push(inv_res)
  }
}
