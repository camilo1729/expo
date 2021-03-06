### This is the first version of the plugin g5k-campaign for Expo
require 'campaign/engine'
require 'resourceset'
require 'expectrl'
require 'observer'
require 'job_notiffier'
require 'DSL'


def api_connect
connection = Restfully::Session.new(
      :configuration_file=> File.expand_path("~/.restfully/api.grid5000.fr.yml")
    )
  return connection
end


class ExpoEngine < Grid5000::Campaign::Engine
  #include Expo
  include Observable ## to test the observable software pattern
  MyExperiment = Experiment.instance
  Console = DSL.instance
  RESOURCE_SET_FILE = ".expo_resource_set"
  EXPO_METADATA = ".expo_metadata"
  G5K_METADATA = ".g5k_metadata-#{Time.now.to_i}"

  attr_accessor :environment, :resources, :walltime, :name, :jobs, :jobs_id, :wait_jobs
  # to ease the definition of the experiment
  set :no_cleanup, true # setting this as the normal used is for interacting
  set :environment, nil # The enviroment is by default nil because if nothing is specifyed there is no deployment.
  # It has to be true for interactive use and false when executed as stand-alone
  set :types , ["allow_classic_ssh"]
  set :logger, Log4r::Logger['Expo_log']
  set :submission_timeout, 7200
  ## I'm rewriting this method otherwise I cannot load the Class again because the defaults get frozen.

  ## @resources will be a hash with the following structure
  ## {:grenoble => ["nodes=1","nodes=1"]   --> This will submit two jobs
  ##  :lille => ["{cluster = 'cluster_1'}/nodes=1"]
  def initialize(gateway=nil,key=nil)
    @resources = { :grenoble => ["nodes=1"] }
    @walltime=3600
    @name = "Expo_Experiment"
    @connection = api_connect
    @mutex = Mutex.new
    @nodes_deployed = []
    @gateway = gateway
    @jobs_id = {} # e.g., {:grenoble => 15706, :lille => 1221}
    @processors = []
    @wait_jobs = true
    add_observer(JobNotifier.new)
    ### Small part to initialize the resourceSet of the experiment
    exp_resource_set = ResourceSet::new(:resource_set,"Expo_resources")
    ## It seems that a name has to be declared in order to be assigned to a Hash
    exp_resource_set.properties[:gateway] = @gateway unless @gateway.nil?
    ### need to initialized the resources properly
    MyExperiment.add_resources(exp_resource_set)
    @public_key = key
    #### I need to check whether I put it here or elsewhere.
    @g5k_metadata = {:environment => [],:resources => [], :job =>[], :site =>[]}

  end

  def create_metadata_file()
    metadata = { :validity => Time.now.to_i + @walltime }
    File.open(EXPO_METADATA,'w+') do |f|
      f.puts(metadata.to_yaml)
    end
  end

  def saving_g5k_metadata(env)
    ## The case multi-site has to be still tested

    @g5k_metadata[:name] = env[:name]
    @g5k_metadata[:user] = env[:user]
    @g5k_metadata[:site].push(env[:site])
    @g5k_metadata[:environment].push(env[:environment])
    @g5k_metadata[:resources].push(env[:resources])
    @g5k_metadata[:walltime] = env[:walltime]
    @g5k_metadata[:public_key] = env[:public_key]
    @g5k_metadata[:job].push(env[:job]['uid'])
    File.open(G5K_METADATA,'w+') do |f|
      f.puts(@g5k_metadata.to_yaml)
    end
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
    # launch parallel reservation on all the sites specifyed
    # the :ignore_thread_exepctions is because sometimes the api throw some exceptions.
    env[:parallel_reserve] = parallel(:ignore_thread_exceptions => true)
    env[:resources].each{ |site, resources|

      resources.each{ |res|
        new_env = env.merge(:site => site.to_s, :resources => res, :uid => @jobs_id[site.to_sym])

        logger.info reserve_log_msg+"Number of nodes to reserve in site: #{site.to_s} => #{res}"
        ## The number resources definitions in each site determined the number of jobs submitted
        MyExperiment.num_jobs_required+=1  ## counting the number of jobs required for the experiment to start
                                           ## in the case it would be synchronous
        env[:parallel_reserve].add(new_env) do |env|

          begin
            env_2=reserve!(env, &block)
           rescue Timeout::Error, StandardError => e
            logger.error "!!! Error submiting job"
            MyExperiment.num_jobs_required-=1  ## we decrease the counter
            changed
            notify_observers(0,logger)
          end

          synchronize {
            self.create_resource_set(env_2[:job],env[:site])
            changed
            notify_observers(env_2[:job]['uid'],logger)
            MyExperiment.jobs.push(env_2[:job]['uid'])
            saving_g5k_metadata(env_2)
          }
          ## Notifying that the task can start
        end

      }


    }
    env[:parallel_reserve].loop! if @wait_jobs
    last_value = true ## just to not make the proc crash

  end

  # rewriting the run code because the default behavior deploys an evironment
  # and Expo does not like that, and also to finally construct the resource set.

  def run!

    if File.exist?(EXPO_METADATA) then
      previous_run_metadata = YAML::load(File.read(EXPO_METADATA))
      if previous_run_metadata[:validity] > Time.now.to_i then
      logger.info "Reusing previous reservation"
        ### replacing resources of the experiment ## Fix-me I have to find a cleaner way to do this
        ## reading g5k metadata
        g5k_metadata =  YAML::load(File.read(Dir.glob(".g5k*").first))
        MyExperiment.resources.resources=YAML::load(File.read(RESOURCE_SET_FILE)).resources
        MyExperiment.jobs = g5k_metadata[:job]
        return true
      end
    end
    reset!

    env = self.class.defaults.dup
    ### copying some variables defined by the user
    env[:environment] = @environment
    env[:walltime] = @walltime
    env[:resources] = @resources
    env[:name] = @name

    env[:public_key] = @public_key unless @public_key.nil?

     unless @jobs_id.empty? then
       env[:no_submit] = true
     end

    envs=[]

    nodes = []

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

          # if @wait then

          # end

        end # reserve!

        #env[:parallel_reserve].loop!

        end_reserve=Time::now()
        logger.info reserve_log_msg +"Total Time Spent waiting for resources #{end_reserve-start_reserve} secs"
        ###############################
      else#if the deployment is defined we do as g5k-campaign
        ### Timing deployment part
        start_deploy=Time::now()
        ### Default user management root
        env = execute_with_hooks(:reserve!, env) do |env|

          env[:nodes] = env[:job]['assigned_nodes']

          env = execute_with_hooks(:deploy!, env) do |env|
            env[:nodes] = env[:deployment]['result'].reject{ |k,v|
              v['state'] != 'OK'
            }.keys.sort

            synchronize { nodes.push(env[:nodes]).flatten! }

            if defined? env[:job]['resources_by_type']['vlans'][0]
              # I have to redifined the resource Set.
              # MyExperiment.each do |node|  ### Need to check this part is using the all resource Set
              #   node.name =
              #     "#{node.name.split('.')[0]}-kavlan-#{env[:job]['resources_by_type']['vlans'][0]}.#{node.properties[:site]}.grid5000.fr"
              # end
            end
          end#deploy!
        end#reserv!
        end_deploy=Time::now()
        logger.info reserve_log_msg +"Total Time Spent deploying #{end_deploy-start_deploy}"
      end# if  environment

      ### Deletes the resources from the Resource Set that had problems in the deployment fase ####
      # $all.delete_if { |resource|
       # not nodes_deployed.include?(resource.name)
      #}

      ##########################

    end #change_dir
    return env
  end

# Redefining cleanup

  def stop!(jobs=nil)
    logger.info "Cleaning previous reservation files"
    # File.delete(RESOURCE_SET_FILE) ## Fix-me I have to find a way to delete those files when dealing with asynchronity
    # File.delete(EXPO_METADATA)

    if jobs.nil? then
      self.cleanup!("Finishing")
      return true
    end
    jobs.each{ |job|
      job_uni  = @jobs.select { |j| j['uid'] == job}.first
      logger.info "Deleting job: #{job_uni['uid']}"
      job_uni.delete
    }
  end

  def aval(options={})
    how_many?(options)
  end

  def defaults
    self.class.defaults.select { |k,v| [:site,:walltime,:environment,:resources,:types].include? k}
  end

  def get_info_processors
    ## Function to get information of the different processors available in Grid'5000
    ## processors[:site => nancy, :clusters => {}
    @connection.root.sites.each{ |site|
      site_info = {:site => site["uid"], :clusters => [] }
      site.clusters.each{ |cluster|
        temp  = cluster.nodes.first["processor"].merge(cluster.nodes.first["architecture"])
        temp.merge!(cluster.nodes.first["main_memory"])
        temp["cluster"] = cluster["uid"]
        site_info[:clusters].push(temp)
      }
      @processors.push(site_info)
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
    @processors.each{ |site|
      site[:clusters].each{ |cluster|
        cluster.delete("instruction_set")
        cluster.delete("version")
      }
    }
    return @processors
  end

  def get_info_cluster(cluster_name)
    cluster = []
    @processors.each{ |p|  cluster = p[:clusters].select{ |k| k["cluster"] == cluster_name}
      break unless cluster.empty?
    }
    return cluster.first unless cluster.nil?
  end


  ## First of all there should be an initialization of the MyExperiment.resources
  ### exp_resource_set = ResourceSet::new
  ### exp_resource_set.properties[:gateway ] = @gateway
  ### MyExperiment.add_resources(exp_resource_set)

  def create_resource_set(job,site_name)
    job_name = job['name']
    job_nodes = job['assigned_nodes']

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
      logger.info "The site does not exits adding it"
      site_set = ResourceSet::new(:site)
      site_set.properties[:id] = job['uid'] if @resources[site_name.to_sym].length < 2 ## there is just one job per site
      site_set.properties[:name] = site_name
      gateway = "frontend.#{site_name}.grid5000.fr"
      site_set.properties[:gateway] = gateway ## Fix-me gateway definition will depend on the context
      #site_set.properties[:ssh_user] = Console.variables[:user]
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
      cluster_set.properties[:gateway] = "localhost" # gateway it is scalable enough
      cluster_set.properties[:ssh_user] = Console.variables[:user]  ## Fix-me for Deploying
      cluster_set.properties[:gw_ssh_user] = Console.variables[:gw_user].nil? ? Console.variables[:user] : Console.variables[:gw_user]
      cluster_set.properties[:hw] = get_info_cluster(cluster)
      job_nodes.each { |node|
        node_hash = {}
        if node =~ /#{cluster}\w*/ then
          ## the finest granularity is the node, a node belongs to a particular job
          ## in a cluster we could have different jobs
          resource = Resource::new(:node, nil, node)
          resource.properties[:gateway] = @gateway
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
        site_set.properties[:hw] = cluster_set.properties[:hw] if @resources[site_name.to_sym].length < 2
        ## When we just have a cluster per site , we assigned the hardware cluster to the site
        site_set.push(cluster_set)
      elsif resource_cluster.is_a?(ResourceSet) then
        cluster_set.each { |node|
          resource_cluster.push(node)
        }
      end

    }

    ### saving resource_set in yaml
    logger.info "Saving resources in yaml"
    File.open(RESOURCE_SET_FILE,'w+') do |f|
      f.puts(MyExperiment.resources.to_yaml)
    end

    create_metadata_file
  end

  def create_resource_set_file(file)
    # Loading yaml file
    list_nodes = YAML::load(File.read(file))
    # getting sites
    regexp_site =/\w*-\w*\.(\w*)\.grid5000.fr/
    regexp_cluster = /(\w*)-\w*/

    list_nodes.each{ |node|

      site = regexp_site.match(node)[1]
      resource_site = MyExperiment.resources.select_resource(:name => site)
      gateway = ""
      if not resource_site then
        logger.info "The site does not exits adding it"
        site_set = ResourceSet::new(:site)
        site_set.properties[:name] = site
        gateway = "frontend.#{site}.grid5000.fr"
        site_set.properties[:gateway] = gateway ## Fix-me gateway definition will depend on the context
        MyExperiment.resources.push(site_set)
      elsif resource_site.is_a?(ResourceSet) then
        gateway = "frontend.#{site}.grid5000.fr"
        site_set = resource_site
      end

      cluster = regexp_cluster.match(node)[1]
      resource_cluster = MyExperiment.resources.select_resource_h(:name => cluster)

      if not resource_cluster then ## it doesn't exist we add cluster_set to the site_set
        cluster_set = ResourceSet::new(:cluster)
        cluster_set.properties[:name] = cluster
        cluster_set.properties[:gateway] = "localhost" # gateway it is scalable enough
        cluster_set.properties[:ssh_user] = Console.variables[:user]  ## Fix-me for Deploying
        cluster_set.properties[:gw_ssh_user] = Console.variables[:gw_user].nil? ? Console.variables[:user] : Console.variables[:gw_user]
        site_set.push(cluster_set)
      elsif resource_cluster.is_a?(ResourceSet) then
        cluster_set = resource_cluster
      end


      #Adding nodes
      if node =~ /#{cluster}\w*/ then
        ## the finest granularity is the node, a node belongs to a particular job
          ## in a cluster we could have different jobs
        resource = Resource::new(:node, nil, node)
        resource.properties[:gateway] = @gateway
        cluster_set.push(resource)
          # node_hash[:name] = node
          # node_hash[:job] = job['uid'] ## I have to check why I'm not taking into account the job_id
          # cluster_hash[:nodes].push(node_hash)
      end
    }

  end


end
