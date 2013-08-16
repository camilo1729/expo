### This is the first version of the plugin g5k-campaign for Expo
require 'campaign/engine'
require 'resourceset'
require 'expectrl'

@options = { 
  :logger => $logger,
  #:data_logger => $data_logger,
  :restfully_config => File.expand_path("~/.restfully/api.grid5000.fr.yml")
}


def api_connect
connection = Restfully::Session.new(
      :configuration_file=> File.expand_path("~/.restfully/api.grid5000.fr.yml")
     # :logger => @options[:verbose] ? @options[:logger] : nil
    )
  return connection
end


class ExpoEngine < Grid5000::Campaign::Engine
  #include Expo
  attr_accessor :environment, :site, :resources, :resources_exp,:walltime, :name, :jobs 
  ##to ease the definition of the experiment
  @resources_exp = []   
  
  set :no_cleanup, true # setting this as the normal used is for interacting
  set :environment, nil # The enviroment is by default nil because if nothing is specifyed there is no deployment.
  # It has to be true for interactive use and false when executed as stand-alone
  set :types , ["allow_classic_ssh"]
  set :logger, Experiment.instance.logger
  #set :data_logger, $data_logger
   
## I'm rewriting this method otherwise I cannot load the Class again because the defaults get frozen.
  def initialize(gateway=nil)
    @site=["grenoble"]
    @resources=["nodes=1"]
    @walltime=3600
    @name = "Expo_Experiment"
    @connection = api_connect
    @mutex = Mutex.new
    @resources_exp = []
    @res
    @nodes_deployed = []
    @gateway = gateway
    @jobs = []
  end
  

# rewriting the reserve part for several reasons:
# - to submit request to serveral sites.
# - to build the resourceSet needed for Expo.
## Try to follow this format for loggin'
# [ <LogActor> ] [ <LogSubject> ] <LogMessage>
  on :reserve! do | env, block|

    reserve_log_msg ="[ Expo Engine Grid5000 API ] "
    logger.info reserve_log_msg +"Asking for Resources"

    @res = [env[:resources]].flatten
    #logger.info "Printing Resources array #{env.inspect}"
    #in case we define the same number of nodes in each site.
    @res = @res*@site.length if @res.length==1 && @site.length>1

    envs = []
    
    env[:parallel_reserve] = parallel(:ignore_thread_exceptions => true)
    # launch parallel reservation on all the sites specifyed
    # the :ignore_thread_exepctions is because sometimes the api throw some exceptions.
    reserv = []
    for i in 1..@site.length
      new_env = env.merge(:site => @site[i-1], :resources => @res[i-1])
      #logger.info new_env.inspect
      logger.info reserve_log_msg+"Number of nodes to reserve in site: #{@site[i-1]} => #{@res[i-1]}"
      env[:parallel_reserve].add(new_env) do |env|
        #sleep 1
        env_2=reserve!(env, &block)
        #subhash = self.convert_to_resource(env_2[:job])
        reserv.push(env_2)
        #synchronize { @resources_expo.merge!(subhash) }
        synchronize { self.convert_to_resource(env_2[:job],env[:site])}
        @jobs.push(env_2[:job].uniq)
        #envs.push(new_env)
        #env_2[:nodes].push(env_2[:job]['assigned_nodes']).flatten! 
        #synchronize{ envs.push(env_2) }
      end
    end
  
    env[:parallel_reserve].loop!
    # construct $all ResourceSet
    puts "Creating resourceSet"
    #@resources_expo
    #puts @resources_expo.inspect
    extract_resources_new(@resources_exp)

    reserv
  end

  # rewriting the run code because the default behavior deploys an evironment 
# and Expo does not like that, and also to finally construct the resource set.

  def run!
    reset!
    
    env = self.class.defaults.dup
    ### copying some variables defined by the user
    env[:environment]=@environment    
    env[:site]=@site
    env[:walltime]=@walltime
    env[:resources]=@resources
    envs=[]
    
    nodes = []
    ## I will comment this lines because I'm working in interactive mode I dont want that my session
    ## will be canceld because of Ctrl+C.
    #%w{ INT TERM}.each do |signal|
    #  Signal.trap( signal ) do
    #    logger.fatal "Received #{signal.inspect} signal. Exiting..."
    #        exit(1)
    #      end
    #end
    
    change_dir do
# I separate the deployment part from the submission part.
## if the environment is not defined we do just the reservation part
      reserve_log_msg ="[ Expo Engine Grid5000 API ] "
      if env[:environment].nil?
### Timing the reservation part
        start_reserve=Time::now()
      
        env = execute_with_hooks(:reserve!,env) do |env|        
        
             env[:nodes] = env[:job]['assigned_nodes']
        
             synchronize{
              nodes.push(env[:nodes]).flatten!
              #envs.push(env)
              }
          #env[:nodes]=nodes
        end # reserve!
      
        end_reserve=Time::now()
        logger.info reserve_log_msg +"Total Time Spent waiting for resources #{end_reserve-start_reserve} secs"
        ###############################
      else#if the deployment is defined we do as g5k-campaign
        ### Timing deployment part
        start_deploy=Time::now()  
        ### Default user management root
        $ssh_user="root"
        env = execute_with_hooks(:reserve!, env) do |env|
          
          env[:nodes] = env[:job]['assigned_nodes']
          
          env = execute_with_hooks(:deploy!, env) do |env|
            env[:nodes] = env[:deployment]['result'].reject{ |k,v|
              v['state'] != 'OK'
            }.keys.sort
            
            synchronize { nodes.push(env[:nodes]).flatten! }
            
            if defined? env[:job]['resources_by_type']['vlans'][0]
              # I have to redifined the resource Set.
              $all.each do |node|
                node.name = 
                  "#{node.name.split('.')[0]}-kavlan-#{env[:job]['resources_by_type']['vlans'][0]}.#{node.properties[:site]}.grid5000.fr"
              end
            end
          end#deploy!
        end#reserv!
        end_deploy=Time::now()
        logger.info reserve_log_msg +"Total Time Spent deploying #{end_deploy-start_deploy}" 
        #data_logger.info "Nodes succesfully deployed"
        #data_logger.info nodes
      end# if  environment
      
      ### Deletes the resources from the Resource Set that had problems in the deployment fase ####
      # $all.delete_if { |resource| 
       # not nodes_deployed.include?(resource.name)  
      #}
      
##########################
                  
    end #change_dir
    #nodes
    return env
  end

# Redefining cleanup

  def stop!(job=nil)
    if job.nil? then
      self.cleanup!("Finishing")
      return true
    end
    job_hash = @jobs.select { |j| j['uid'] == job}.first
    puts "Deleting job: #{job_hash['uid']}"
    #job_hash.delete
    self.cleanup!("Finish",job_hash)
    ## cleaning up the variable $all
    # $all=ResourceSet::new()
  end

  def aval(options={})
    how_many?(options)
  end

  def defaults  
    self.class.defaults.select { |k,v| [:site,:walltime,:environment,:resources,:types].include? k}    
  end  

  def get_processors
    ## Function to get the different processors available in Grid'5000
    processors = []
    ## processors[:site => nancy, :clusters => {}
    @connection.root.sites.each{ |site|
      site_info = {:site => site["name"].downcase, :clusters => [] }
      site.clusters.each{ |cluster|
        temp  = cluster.nodes.first["processor"].merge(cluster.nodes.first["architecture"])
        #temp["site"] = site["name"]
        temp["cluster"] = cluster["uid"]
        site_info[:clusters].push(temp)
        #processors.push(temp)
      }
      processors.push(site_info)
    }
    #processors.uniq!
    ## this have to be replace, fourtunately there is just one processor repeated thereofre is not worthy
    ## to do it in Grid5000
    # vector = []
    # processors.each { |site|
    #   site[:clusters].each{ |cluster|
    #     vector.push(cluster)
    #   }
    # }
    # new_v= vector.uniq { |k| k["clock_speed"]}
    # ## Repeated element
    # r_element = vector-new_v
    ## Deleting some irrelevant information.
    processors.each{ |site|
      site[:clusters].each{ |cluster|
        cluster.delete("instruction_set")
        cluster.delete("version")
      }
    }
    return processors
  end

  def extract_resources_new(resources)
    exp_resource_set = ResourceSet::new
    exp_resource_set.properties[:gateway ] = @gateway
    resources.each { |site|
      puts "putting site: #{site[:name]} into resource Set"
      site_set = ResourceSet::new
      site_set.properties[:id] = site[:jobs].first ## Fix-me
      site_set.properties[:name] = site[:name]
      site_set.properties[:type] = :site
      gateway = "frontend.#{site[:name]}.grid5000.fr"
      site_set.properties[:gateway] = gateway ## Fix-me gatway definition will depend on the context
      
      site_set.properties[:ssh_user] = "cruizsanabria"
      site[:clusters].each{ |cluster|
        cluster_set = ResourceSet::new
        cluster_set.properties[:name] = cluster[:name]
        cluster_set.properties[:gateway] = gateway
        cluster_set.properties[:type] = :cluster
        cluster_set.properties[:ssh_user] ="cruizsanabria"
        cluster_set.properties[:gw_ssh_user] ="cruizsanabria"
        cluster[:nodes].each{ |node|
          resource = Resource::new(:node, nil, node[:name])
          resource.properties[:gateway] = gateway
          #resource
          cluster_set.push(resource)
        }
        site_set.push(cluster_set)
      }
      exp_resource_set.push(site_set)
    }
    Experiment.instance.add_resources(exp_resource_set)
  end
          
  #             gw = /\w*\.(\w+)\.\w*/.match(node)
  #             gateway = "frontend."+gw[1]+".grid5000.fr"
  #             resource.properties[:site] = gw[1]
  #             resource_set.properties[:site] = gw[1]
  #             resource.properties[:gateway] = gateway
  #             resource_set.properties[:gateway] = gateway
  #             resource_set.push(resource)
  #       
  # def extract_resources_new(resources)
  #   puts "Extracting resources "
  #   temp_resourceset=ResourceSet::new
  #   temp_resourceset.properties[:gateway]=@gateway
  #   resources.each { |site|
  #     site_set = ResourceSet::new
  #     site_set.properties[:id] = 
  #   result.each { |key,value|
  #     # { "cluster" => {...} }                                                                                    
  #     cluster = key
  #     value.each { |key,value|
  #       # { "job_id" => {...} }                                                                
  #       jobid = key
  #       resource_set = ResourceSet::new
  #       resource_set.properties[:id] = jobid
  #       resource_set.properties[:alias] = cluster
  #       ### need to manage the definiion of the users to access the machine
  #       if @environment.nil? then
  #         resource_set.properties[:ssh_user] = "cruizsanabria"
  #       else
  #         resource_set.properties[:ssh_user] = "root"
  #       end

  #       resource_set.properties[:gw_ssh_user] =  "cruizsanabria"
  #       value.each { |key,value|
  #         # { "name" => "...", "gateway" => "...", "nodes" => "...",
  #         case key
  #         when "name"
  #           resource_set.name = value
  #           #when "gateway"
  #           #  resource_set.properties[:gateway] = value
  #         when "nodes"
  #           value.each { |node|
  #             resource = Resource::new(:node, nil, node)
  #             # here we must construct gateway's name in place   
  #             gw = /\w*\.(\w+)\.\w*/.match(node)
  #             gateway = "frontend."+gw[1]+".grid5000.fr"
  #             resource.properties[:site] = gw[1]
  #             resource_set.properties[:site] = gw[1]
  #             resource.properties[:gateway] = gateway
  #             resource_set.properties[:gateway] = gateway
  #             resource_set.push(resource)
  #           }
  #         end
  #       }
  #       # puts resource_set.inspect
        
  #       temp_resourceset.push(resource_set)
  #     }
  #   }
  #   ## putting all the resources in to the class experiment
  #     
  #   end

  def convert_to_resource(job,site_name)

    # site hash
    # site_hash = { :name => site,
    #   :jobs => [] intergers
    #   :clusters => []}
  
    # first I have to verify if the site already exist in the array resources
    # @resources_exp = []
    job_name = job['name']
    job_nodes = job['assigned_nodes']
    puts "#{job_nodes.inspect}"
    # job_id will be the same for all the clusters of one site                                                                            
  
    job_id = job['uid']

    clusters = []

    regexp = /(\w*)-\w*/
    job_nodes.each { |node|
      cl = regexp.match(node)
      clusters.push(cl[1])
    }

    clusters.uniq!

    clusters_struct = []
    clusters.each{ |cluster|
      cluster_hash = {}
      cluster_hash[:name] = cluster
      cluster_hash[:nodes] = []
      job_nodes.each { |node|
        node_hash = {}
        if node =~ /#{cluster}\w*/ then
          ## the finest granularity is the node, a node belongs to a particular job
          ## in a cluster we could have different jobs
          node_hash[:name] = node
          node_hash[:job] = job['uid']
          cluster_hash[:nodes].push(node_hash)
        end
      }

      clusters_struct.push(cluster_hash)
    }

    index_site = @resources_exp.index{ |site| site[:name] == site_name }
    
    if index_site.nil? then ## new site in the resources
      site_hash = {:jobs =>[]}
      site_hash[:name] = site_name
      site_hash[:jobs].push(job['uid'])
      site_hash[:clusters] = clusters_struct
      @resources_exp.push(site_hash)
    else
      ## we have to get the site form the resource_exp
      ## res is the site that already is on the resources_exp
      @resources_exp[index_site][:jobs].push(job['uid'])
        
      clusters_struct.each{ |cluster_hash|
        index_cluster = @resources_exp[index_site][:clusters].index { |cluster| cluster[:name] == cluster_hash[:name] }
        if index_cluster.nil? then ## there is no such a cluster we have to add it
          @resources_exp[index_site][:clusters].push(cluster_hash)
        else
          @resources_exp[index_site][:clusters][index_cluster][:nodes]+= cluster_hash[:nodes]
        end
      }

          
    end
  end                        
end
  # will contain hash like         
  # {                                               
  #   "paradent" => {                                                                                                                    
  #     345212 => {                                                                                                                       
  #       "name" => "job_name",                                                                                                           
  #       "nodes" => [ "paradent-1", "paradent-12"                                                                                        
  #     }                                                                                                                                 
  #   }                                                                                                                                   
  #   "parapluie" => {                                                                                                                    
  #     345212 => ...                                                                                                                     
  # site_resources = {}
  # site_resources[:clusters] = []
  # clusters.each { |cluster|
  #   #first sub-hash                                                                                                                       
  #   uid_hash = {}
  #   #second sub-hash                                                                                                                      
  #   nodes_hash = {}
  #   nodes_hash["name"] = job_name
  #   job_nodes.each { |node|
  #     #find out the cluster to which this node belongs                                                                                    
  #     if node =~ /#{cluster}\w*/
  #       #if there are already nodes in this cluster - add in array                                                                        
  #       if nodes_hash.has_key?("nodes")
  #         nodes_hash["nodes"].push(node)
  #       #if this node is the first in this cluster - create an array                                                                      
  #       #of nodes with this node and add the array to hash                                                                                
  #       else
  #         nodes_array = []
  #         nodes_array.push(node)
  #         nodes_hash["nodes"] = nodes_array
  #       end
  #     end
  #   }
  #   uid_hash[job_id] = nodes_hash
  #   if !(clusters_hash.has_key?(cluster))
  #     clusters_hash[cluster] = uid_hash
  #   end
  # }
  # site_resources={:site => site,:clusters=>clusters_hash}
  #   end

  
  #end

#---------------Helper routines defined in the Expo module -----------

# Creating 'resources' from the assigned nodes to put them after into                                                                    
# $all ResourceSet                                                                                                                        

#module Expo 
 

# def extract_resources_new(result)
#   result.each { |key,value|
#     # { "cluster" => {...} }                                                                                                              
#       cluster = key
#     value.each { |key,value|
#       # { "job_id" => {...} }                                                                                                             
#         jobid = key
#         resource_set = ResourceSet::new
#         resource_set.properties[:id] = jobid
#         resource_set.properties[:alias] = cluster
        
#       value.each { |key,value|
#         # { "name" => "...", "gateway" => "...", "nodes" => "...",                                                                        
#           case key
#           when "name"
#             resource_set.name = value
#           #when "gateway"                                                                                                                 
#           #  resource_set.properties[:gateway] = value                                                                                    
#           when "nodes"
#             value.each { |node|
#               resource = Resource::new(:node, nil, node)
#               # here we must construct gateway's name in place                                                                            
#               gw = /\w*\.(\w+)\.\w*/.match(node)
#               gateway = "frontend."+gw[1]+".grid5000.fr"
#               resource.properties[:site] = gw[1]
#               resource_set.properties[:site] = gw[1]
#               resource.properties[:gateway] = gateway
#               resource_set.properties[:gateway] = gateway
#               resource_set.push(resource)
#           }
#           end
#       }
#         $all.push(resource_set)
#     }
#   }
# end
#end



