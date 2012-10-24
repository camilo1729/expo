### This is the first version of the plugin g5k-campaign for Expo
require 'grid5000/campaign/engine'

logger = Logger.new(STDERR)
logger.level = Logger.const_get(ENV['DEBUG'] || "INFO")

@options = { 
  :logger => logger,
  :restfully_config => File.expand_path("~/.restfully/api.grid5000.fr.yml")
}

def api_connect
@connection = Restfully::Session.new(
      :configuration_file=> @options.delete(:restfully_config),
      :logger => @options[:verbose] ? @options[:logger] : nil
    )
end


class ExpoEngine < Grid5000::Campaign::Engine
  include Expo
  attr_accessor :environment, :site, :resources, :walltime 
  ##to ease the definition of the experiment
  @resources_expo = {}   

  set :no_cleanup, true # setting this as the normal used is for interacting
  set :environment, nil # The enviroment is by default nil because if nothing is specifyed there is no deployment.
  # It has to be true for interactive use and false when executed as stand-alone
  set :types , ["allow_classic_ssh"]
   
  ## I'm rewriting this method otherwise I cannot load the Class again because the faults get frozen.
  def initialize(connection)
    puts "initializing"    
    @connection = connection
    @mutex = Mutex.new
    @resources_expo = {}
    @res
  end
  

# rewriting the reserve part for several reasons:
# - to submit request to serveral sites.
# - to build the resourceSet needed for Expo.
  on :reserve! do | env, block|
    logger.info "Doing reservation for Expo"
    @res = [env[:resources]].flatten
    #in case we define the same number of nodes in each site.
    @res = @res*@site.length if @res.length==1 && @site.length>1

    env[:parallel_reserve] = parallel
    # launch parallel reservation on all the sites specifyed
    for i in 1..@site.length
      new_env = env.merge(:site => @site[i-1], :resources => @res[i-1])
      env[:parallel_reserve].add(new_env) do |env|
        env_2=reserve!(env, &block)
        subhash = self.convert_to_resource(env_2[:job], env[:site])
        synchronize { @resources_expo.merge!(subhash) }
      end
    end
  
    env[:parallel_reserve].loop!
    env
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
    nodes = []
    %w{ INT TERM}.each do |signal|
      Signal.trap( signal ) do
        logger.fatal "Received #{signal.inspect} signal. Exiting..."
            exit(1)
          end
    end
    
    logger.debug self.inspect
    
    change_dir do 
      env = execute_with_hooks(:reserve!,env) do |env|
        env[:nodes] = env[:job]['assigned_nodes']
        
      end #:reserve!
      synchronize { 
        nodes.push(env[:nodes]).flatten!
      }
    end #change_dir
    nodes
    # construct $all ResourceSet        
    self.extract_resources_new(@resources_expo)
  end
  
end

#---------------Helper routines defined in the Expo module -----------

# Creating 'resources' from the assigned nodes to put them after into                                                                      # $all ResourceSet                                                                                                                         

module Expo 
 
def convert_to_resource(job, site)

  job_name = job['name']
  job_nodes = job['assigned_nodes']
  # job_id will be the same for all the clusters of one site                                                                                
  job_id = job['uid']

  clusters = []

  regexp = /(\w*)-\w*/
  job_nodes.each { |node|
    cl = regexp.match(node)
    clusters.push(cl[1])
  }

  clusters.uniq!

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
  clusters_hash = {}
  clusters.each { |cluster|
    #first sub-hash                                                                                                                        
    uid_hash = {}
    #second sub-hash                                                                                                                       
    nodes_hash = {}
    nodes_hash["name"] = job_name
    job_nodes.each { |node|
      #find out the cluster to which this node belongs                                                                                     
      if node =~ /#{cluster}\w*/
        #if there are already nodes in this cluster - add in array                                                                         
        if nodes_hash.has_key?("nodes")
          nodes_hash["nodes"].push(node)
        #if this node is the first in this cluster - create an array                                                                       
        #of nodes with this node and add the array to hash                                                                                 
        else
          nodes_array = []
          nodes_array.push(node)
          nodes_hash["nodes"] = nodes_array
        end
      end
    }
    uid_hash[job_id] = nodes_hash
    if !(clusters_hash.has_key?(cluster))
      clusters_hash[cluster] = uid_hash
    end
  }
  clusters_hash
end



def extract_resources_new(result)
  result.each { |key,value|
    # { "cluster" => {...} }                                                                                                              
      cluster = key
    value.each { |key,value|
      # { "job_id" => {...} }                                                                                                             
        jobid = key
        resource_set = ResourceSet::new
        resource_set.properties[:id] = jobid
        resource_set.properties[:alias] = cluster

      value.each { |key,value|
        # { "name" => "...", "gateway" => "...", "nodes" => "...",                                                                        
          case key
          when "name"
            resource_set.name = value
          #when "gateway"                                                                                                                   
          #  resource_set.properties[:gateway] = value                                                                                      
          when "nodes"
            value.each { |node|
              resource = Resource::new(:node, nil, node)
              # here we must construct gateway's name in place                                                                              
              gw = /\w*\.(\w+)\.\w*/.match(node)
              gateway = "frontend."+gw[1]+".grid5000.fr"
              resource.properties[:site] = gw[1]
              resource_set.properties[:site] = gw[1]
              resource.properties[:gateway] = gateway
              resource_set.properties[:gateway] = gateway
              resource_set.push(resource)
          }
          end
      }

        $all.push(resource_set)
    }
  }
end
end
