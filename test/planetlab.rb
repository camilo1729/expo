# -*- coding: utf-8 -*-

require 'expo'
require 'planetlab_api'

task :get_resources do
  get_resources
end

set :result, nil

task :main do

  File.open("Planetlab_avail.txt",'w'){ |f|
    240.times{
      datame = Time::now.to_i
      task :simple, :target => Experiment.resources do
        result =run("hostname")
      end
      time =result.totalduration
      f.puts ”#{datame} \ t #{time} \ t#{res.length}”
      sleep(60)
    }

end
