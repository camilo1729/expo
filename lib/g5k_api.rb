### This is the first version of the plugin g5k-campaign for Expo
require 'campaign/engine'
require 'resourceset'
require 'expectrl'
require 'observer'
require 'job_notiffier'

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
  include Observable ## to test the observable software pattern
  MyExperiment = Experiment.instance
  attr_accessor :environment, :resources, :resources_exp, :walltime, :name, :jobs
  ##to ease the definition of the experiment
  @resources_exp = []   
  
  set :no_cleanup, true # setting this as the normal used is for interacting
  set :environment, nil # The enviroment is by default nil because if nothing is specifyed there is no deployment.
  # It has to be true for interactive use and false when executed as stand-alone
  set :types , ["allow_classic_ssh"]
  set :logger, MyExperiment.logger
  set :submission_timeout, 3600*24 
  #set :data_logger, $data_logger
   
  ## I'm rewriting this method otherwise I cannot load the Class again because the defaults get frozen.

  ## @resources will be a hash with the following structure
  ## {:grenoble => ["nodes=1","nodes=1"]   --> This will submit two jobs
  ##  :lille => ["{cluster = 'cluster_1'}/nodes=1"]
  def initialize(gateway=nil)
    @resources = { :grenoble => ["nodes=1"] }
    @walltime=3600
    @name = "Expo_Experiment"
    @connection = api_connect
    @mutex = Mutex.new
    @resources_exp = []
    @res
    @nodes_deployed = []
    @gateway = gateway
#    @jobs = []
    add_observer(JobNotifier.new)

    ### Small part to initialize the resourceSet of the experiment
    exp_resource_set = ResourceSet::new(:resource_set,"Exp_resources")
    ## It seems that a name has to be declared in order to be assigned to a Hash
    exp_resource_set.properties[:gateway ] = @gateway
    MyExperiment.add_resources(exp_resource_set)
    #### I need to check whether I put it here or elsewhere.
  end
  

# rewriting the reserve part for several reasons:
# - to submit request to serveral sites.
# - to build the resourceSet needed for Expo.
## Try to follow this format for loggin'
# [ <LogActor> ] [ <LogSubject> ] <LogMessage>
  on :reserve! do | env, block|

    reserve_log_msg ="[ Expo Engine Grid5000 API ] "
    logger.info reserve_log_msg +"Asking for Resources"

    envs = []
    
    env[:parallel_reserve] = parallel(:ignore_thread_exceptions => true)
    # launch parallel reservation on all the sites specifyed
    # the :ignore_thread_exepctions is because sometimes the api throw some exceptions.
    reserv = []

    env[:resources].each{ |site, resources|
      
      resources.each{ |res|
        new_env = env.merge(:site => site.to_s, :resources => res)
    
        logger.info reserve_log_msg+"Number of nodes to reserve in site: #{site.to_s} => #{res}"
        ## The number resources definitions in each site determined the number of jobs submitted
        MyExperiment.num_jobs_required+=1  ## counting the number of jobs required for the experiment to start 
                                           ## in the case it would be synchronous
        env[:parallel_reserve].add(new_env) do |env|
          
          env_2=reserve!(env, &block)
          reserv.push(env_2)
          synchronize { self.create_resource_set(env_2[:job],env[:site])}
#          @jobs.push(env_2[:job])
          ## putting jobs number into experiment structure
          @jobs.each{ |job| MyExperiment.jobs_2.push(job['uid']) }
          changed
          notify_observers(env_2[:job],logger)
          ## Notifying that the task can start
          # Here I can put the notifier that send the event to execute the task
        end
      }  
    }
      
  end

  # rewriting the run code because the default behavior deploys an evironment 
  # and Expo does not like that, and also to finally construct the resource set.

  def run!
    reset!
    
    env = self.class.defaults.dup
    ### copying some variables defined by the user
    env[:environment]=@environment    
    # env[:site]=@site
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
            
          }
          
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
              MyExperiment.each do |node|  ### Need to check this part is using the all resource Set
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
    job_uni  = @jobs.select { |j| j['uid'] == job}.first
    puts "Deleting job: #{job_uni['uid']}"
    job_uni.delete
    #self.cleanup!("Finish",job_hash)
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
        temp["cluster"] = cluster["uid"]
        site_info[:clusters].push(temp)
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
  
  ## First of all there should be an initialization of the MyExperiment.resources
  ### exp_resource_set = ResourceSet::new
  ### exp_resource_set.properties[:gateway ] = @gateway
  ### MyExperiment.add_resources(exp_resource_set)

  def create_resource_set(job,site_name)
    job_name = job['name']
    job_nodes = job['assigned_nodes']
    puts "#{job_nodes.inspect}"
    puts "Entering create jobs "
    # job_id will be the same for all the clusters of one site                                                                            
  
    job_id = job['uid']
    clusters = []

    ## It needs to find out where to put the id of the job
    ## It could be in the site, if there is just one job per site
    ## It could be int he cluster, if there is multiple jobs per site

    resource_site = MyExperiment.resources.select_resource(:name => site_name)
    ## if the site already exits in the resource set this will return a resourceSet 
    ## Otherwise I will return an array
    gateway = ""
    if not resource_site then ## puff it exists
      puts "The site doesnt exits adding it"
      site_set = ResourceSet::new(:site)
      site_set.properties[:id] = job['uid'] if @resources[site_name.to_sym].length < 2 ## there is just one job per site
      site_set.properties[:name] = site_name
      gateway = "frontend.#{site_name}.grid5000.fr"
      site_set.properties[:gateway] = gateway ## Fix-me gatway definition will depend on the context
      site_set.properties[:ssh_user] = "cruizsanabria"
      MyExperiment.resources.push(site_set)
    elsif resource_site.is_a?(ResourceSet) then
      gateway = "frontend.#{site_name}.grid5000.fr"
      site_set = resource_site
    end
    

    regexp = /(\w*)-\w*/
    job_nodes.each { |node|
      cl = regexp.match(node)
      clusters.push(cl[1])
    }

    clusters.uniq!
    
    clusters_struct = []
    clusters.each{ |cluster|
      cluster_set = ResourceSet::new(:cluster)
      cluster_set.properties[:id] = job['uid'] if @resources[site_name.to_sym].length > 1 ## there are several jobs per site
      cluster_set.properties[:name] = cluster
      cluster_set.properties[:gateway] = gateway
      cluster_set.properties[:ssh_user] ="cruizsanabria"
      cluster_set.properties[:gw_ssh_user] ="cruizsanabria"
      job_nodes.each { |node|
        node_hash = {}
        if node =~ /#{cluster}\w*/ then
          ## the finest granularity is the node, a node belongs to a particular job
          ## in a cluster we could have different jobs
          resource = Resource::new(:node, nil, node)
          resource.properties[:gateway] = gateway
          #resource
          cluster_set.push(resource)
          # node_hash[:name] = node
          # node_hash[:job] = job['uid'] ## I have to check why I'm not taking into account the job_id 
          # cluster_hash[:nodes].push(node_hash)
        end
      }

      clusters_struct.push(cluster_set) ## this is an array of resources sets
    }

    
    clusters_struct.each{ |cluster_set|
      ## here the method select_resource return a reference of the self object
      resource_cluster = MyExperiment.resources.select_resource(:name => cluster_set.name)
      if not resource_cluster then ## it doesn't exist we add cluster_set to the site_set
        site_set.push(cluster_set)
      elsif resource_cluster.is_a?(ResourceSet) then 
        cluster_set.each { |node|
          resource_cluster.push(node)
        }
      end

    }
  
  end
  
end


