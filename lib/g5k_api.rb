### This is the first version of the plugin g5k-campaign for Expo
require 'campaign/engine'



@options = { 
  :logger => $logger,
  :data_logger => $data_logger,
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
  attr_accessor :environment, :site, :resources, :walltime, :name 
  ##to ease the definition of the experiment
  @resources_expo = {}   

  set :no_cleanup, true # setting this as the normal used is for interacting
  set :environment, nil # The enviroment is by default nil because if nothing is specifyed there is no deployment.
  # It has to be true for interactive use and false when executed as stand-alone
  set :types , ["allow_classic_ssh"]
  set :logger, $logger
  set :data_logger, $data_logger
   
  ## I'm rewriting this method otherwise I cannot load the Class again because the defaults get frozen.
  def initialize(connection)
    @site=["grenoble"]
    @resources=["nodes=1"]
    @walltime=3600
    @name = "Expo_Experiment"
    @connection = connection
    @mutex = Mutex.new
    @resources_expo = {}
    @res
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
    for i in 1..@site.length
      new_env = env.merge(:site => @site[i-1], :resources => @res[i-1])
      #logger.info new_env.inspect
      logger.info reserve_log_msg+"Number of nodes to reserve in site: #{@site[i-1]} => #{@res[i-1]}"
      env[:parallel_reserve].add(new_env) do |env|
        env_2=reserve!(env, &block)
        subhash = self.convert_to_resource(env_2[:job], env[:site])
        synchronize { @resources_expo.merge!(subhash) }
        envs.push(new_env)
      end
    end
  
    env[:parallel_reserve].loop!
    # construct $all ResourceSet        
    self.extract_resources_new(@resources_expo)
    #logger.info "Printing $all"
    #logger.info $all
    env
  end

  # on :deploy! do | env, block|
  #   logger.info "Starting deploying "
  #   logger.info "This is gonna show something before the deployment"
  #   logger.info "For example the resource Set"
  #   logger.info "#{$all.inspect}"
  #   logger.info "Done"
  #   deploy!(env, &block)
    
  #end

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
    nodes = []
    ## I will comment this lines because I'm working in interactive mode I dont want that my session
    ## will be canceld because of Ctrl+C.
    #%w{ INT TERM}.each do |signal|
    #  Signal.trap( signal ) do
    #    logger.fatal "Received #{signal.inspect} signal. Exiting..."
    #        exit(1)
    #      end
    #end
    
    #logger.debug self.inspect
    #logger.info self

    change_dir do
# I separate the deployment part from the submission part.

### Timing the reservation part
      start_reserve=Time::now()

      env = execute_with_hooks(:reserve!,env) do |env|
        env[:nodes] = env[:job]['assigned_nodes']
        synchronize{
          nodes.push(env[:ndoes]).flatten!
        }
      end # reserve!
      
      end_reserve=Time::now()
      reserve_log_msg ="[ Expo Engine Grid5000 API ] "
      logger.info reserve_log_msg +"Time Spent waiting for resources #{end_reserve-start_reserve} secs"
###############################

### Timing deployment part
      start_deploy=Time::now()
      
      unless env[:environment].nil?
          env = execute_with_hooks(:deploy!, env) do |env|
            env[:nodes]= env[:deployment]['result'].reject{ |k,v|
              v['state'] != 'OK'
            }.keys.sort
          end # :deploy!
      end
      
      end_deploy=Time::now()
      logger.info reserve_log_msg +"Time Spent deploying #{end_deploy-start_deploy}"      
##########################
      
      if defined? env[:job]['resources_by_type']['vlans'][0]
         # I have to redifined the resource Set.
          $all.each do |node|
          node.name = 
          "#{node.name.split('.')[0]}-kavlan-#{env[:job]['resources_by_type']['vlans'][0]}.#{node.properties[:site]}.grid5000.fr"
        end
      end
                  
    end #change_dir
    #nodes
    return env
  end

# Redefining cleanup

  def stop!
    self.cleanup!("finishing")
    ## cleaning up the variable $all
    $all=ResourceSet::new()
  end

  def defaults  
    self.class.defaults.select { |k,v| [:site,:walltime,:environment,:resources,:types].include? k}    
  end  
  
end

#---------------Helper routines defined in the Expo module -----------

# Creating 'resources' from the assigned nodes to put them after into                                                                    
# $all ResourceSet                                                                                                                        

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



