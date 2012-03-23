require 'rubygems'
require 'pp'
#require 'restfully'
require 'thread'
require "xmlrpc/client"
require 'parseconfig'

def get_resources
    Expo.get_machines()
end

module Expo


def self.get_machines

   #puts "Putting some planet lab nodes in the resources variable"
   server = XMLRPC::Client.new2("https://www.planet-lab.eu/PLCAPI/")
   #gettring the parameters from configuration file
   file_path=File.expand_path('~/.planetlab-API.cfg')
   puts "File path : #{file_path}"

   config_pl=ParseConfig.new(file_path)
   auth={}
   auth['Username'] = config_pl.get_value('username')
   auth['AuthMethod']= "password"
   auth['AuthString']= config_pl.get_value('password')

   query=server.call("GetSlices",auth,{'name'=>"lig_expe"},['node_ids'])
   node_ids=query[0]['node_ids']
   nodes_hostnames=server.call("GetNodes",auth,{'node_id'=>node_ids},['hostname'])

   nodes = nodes_hostnames.map{ |item| item.values }.flatten
 

   nodes.each{ |node|
	resource = Resource::new(:node, nil, node)
	#puts "Adding #{node}"
	$all.push(resource)
   }
end

  def check( nodes )
	n = nodes.flatten(:node).uniq
	puts "Testing: " + n.inspect

	test_nis = "ruby taktuk2yaml.rb -s"
	
	 test_nis += $ssh_connector
  	n.each(:node) { |x|
    		test_nis += " -m #{x}"
  	}
  	test_nis += " broadcast exec [ date ]"
  	command_result = $client.asynchronous_command(test_nis)
  	$client.command_wait(command_result["command_number"],1)
	result = $client.command_result(command_result["command_number"])
	tree = YAML::load( result["stdout"] )
  #            #puts "dates :"
  #              #puts result["stdout"];
  #                
        puts "Failing nodes :"
        tree["connectors"].each_value { |error|
 
	if error["output"].scan("Connection timed out").pop or error["output"].scan("Connection closed by remote host").pop or error["output"].scan("Permission denied").pop or error["output"].scan("Name or service not known").pop
 		nodes.delete_if {|resource| resource.name == error["peer"] }
                puts error["peer"]+" : "+error["output"]
         end
        }
       return nil
 end
  

end
