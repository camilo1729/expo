# -*- coding: utf-8 -*-
require 'restfully'
require 'json'
require 'logger'
require 'ap' # awesome_print
require 'net/ssh'
require 'net/scp'
require 'net/sftp'
require 'net/ssh/gateway'
require 'net/ssh/multi'
require 'uri'
require 'thread'

require 'campaign/parallel'


module Grid5000

  module Campaign

    class Error < StandardError; end
    class HookError < Error; end

    class Engine


      # = User attributes
      #
      # == Usage
      #
      #   class MyEngine < Grid5000::Campaign::Engine
      #     set :attribute1, value
      #   end
      #
      # Values of other attributes can be accessed via <tt>defaults[attribute]</tt>
      #
      # == Semantics
      # <tt>environment</tt>:: a name or URI of an environment to deploy [default=<tt>squeeze-x64-base</tt>].
      # <tt>public_key</tt>:: a URI to the SSH public key to be used (file or http(s) scheme). Will be inferred from your ~/.ssh if not explicitely set [optional].
      # <tt>private_key</tt>:: path to the private part of your SSH public key. Will be inferred from your ~/.ssh if not explicitely set [optional].
      # <tt>resources</tt>:: description of the resources to book in your job [default=<tt>nodes=1</tt>].
      # <tt>properties</tt>:: a string of OAR properties (e.g. '-p ...').
      # <tt>walltime</tt>:: duration in seconds of your job [default=<tt>3600</tt>].
      # <tt>user</tt>:: Grid'5000 username [default=<tt>ENV['USER']</tt>].
      # <tt>notifications</tt>:: array of notification URIs [optional]. Valid URI schemes include: <tt>HTTP</tt>, <tt>MAILTO</tt>, <tt>XMPP</tt>.
      # <tt>site</tt>:: site id on which to launch the campaign [default=<tt>rennes</tt>].
      # <tt>no_submit</tt>:: attempts to reuse an existing running job on the same site, with the same name and the same owner. Will launch a new job if none found [default=<tt>false</tt>].
      # <tt>no_deploy</tt>:: attempts to reuse an existing deployment on the same site, on the same nodes, with the same owner. Will launch a new deployment if none found [default=<tt>false</tt>].
      # <tt>no_install</tt>:: do not launch the install phase [default=<tt>false</tt>].
      # <tt>no_execute</tt>:: do not launch the execute phase [default=<tt>false</tt>].
      # <tt>no_cleanup</tt>:: do not automatically delete all your jobs and deployments at the end of your campaign (if everything went well) [default=<tt>false</tt>].
      # <tt>no_cancel</tt>:: do not automatically delete all your jobs and deployments if an error occurs [default=<tt>false</tt>].
      # <tt>name</tt>:: name of your campaign [default=<tt>class.name</tt>]
      # <tt>gateway</tt>:: the hostname of a gateway to use when issuing SSH, SFTP, and SCP commands [default=none].
      # <tt>logger</tt>:: an object that acts as a the <tt>Logger</tt> standard ruby library.
      # <tt>submission_timeout</tt>:: maximum duration (in seconds) to wait for a job to be running [defaut=<tt>5*60</tt>].
      # <tt>deployment_timeout</tt>:: maximum duration (in seconds) to wait for a deployment to be terminated [defaut=<tt>15*60</tt>].
      # <tt>deployment_min_threshold</tt>:: minimum percentage of nodes that must have been correctly deployed, for the deployment to be considered succesful [default=<tt>1</tt> (100%)]
      # <tt>deployment_max_attempts</tt>:: maximum number of attempts that must be made if the deployment fails [default=<tt>1</tt>]
      # <tt>ssh_max_attemps</tt>:: maximum number of attempts that must be made if a host is unreachable when trying to connect via SSH [default=<tt>3</tt>].
      # <tt>chdir</tt>:: the directory in which the engine code should be executed [default=<tt>ENV['PWD']</tt> or engine directory if custom engine is loaded].
      # <tt>polling_frequency</tt>:: interval (in seconds) between two polls on a resource to check its state [default=<tt>5</tt>].
      #
      USER_ATTRIBUTES = [
        :environment,
        :public_key,
        :private_key,
        :resources,
        :properties,
        :user,
        :walltime,
        :notifications,
        :site,
        :no_submit,
        :no_deploy,
        :no_cancel,
        :no_install,
        :no_execute,
        :no_cleanup,
        :name,
        :gateway,
        :logger,
        :data_logger,
        :submission_timeout,
        :deployment_max_attempts,
        :deployment_min_threshold,
        :deployment_timeout,
        :ssh_max_attempts,
        :chdir,
                         :jobs, ## Testing Expo
        :polling_frequency
      ]

      USER_ATTRIBUTES.each do |uattr|
        define_method(uattr) { self.class.defaults[uattr] }
      end

      class << self
        def parent(method)
          if superclass.respond_to?(method)
            superclass.send(method)
          else
            nil
          end
        end


        # @return [Hash] the hash of default options set.
        def defaults
          @defaults ||= deep_copy(parent(:defaults) || {}).merge(
            :name => self.name
          )
        end

        # Sets a new <tt>value</tt> for a default <tt>attribute</tt>. Hello
        # E.g.
        #   set :site, "nancy"
        #   set :walltime, 7200
        def set(attribute, value)
          unless defaults.has_key?(attribute)
            define_method(attribute) { self.class.defaults[attribute] }
          end
          defaults[attribute.to_sym] = value
        end

        # @return [Logger, nil] logger the logger object.
        def logger
          defaults[:logger]
        end

        #### Fix me adding temporary data logger ###
        
        def data_logger
          defaults[:data_logger]
        end

        # Register a hook to be executed *before* method <tt>name</tt>.
        # @param [String] name the name of the method.
        # @param [Proc] block the block that will be called.
        # @yield [Hash, *args] the environment hash, plus optional arguments.
        # @yieldreturn [Hash] the block MUST return the environment hash.
        def before(name, &block)
          before_hooks[name] ||= []
          before_hooks[name].push(block)
        end

        # Register a hook to be executed *instead* of method <tt>name</tt>
        # The original method <tt>name</tt> should be explicitely called by the user within the hook, or nothing will happen.
        # @param [String] name the name of the method.
        # @param [Proc] block the block that will be called.
        # @yield [Hash, Proc] the environment hash and original block to be called when the method yields.
        # @yieldreturn [Hash] the block MUST return the environment hash.
        def on(name, &block)
          on_hooks[name] ||= []
          on_hooks[name].push(block)
        end

        # Register a hook to be executed *after* method <tt>name</tt>.
        # @param [String] name the name of the method.
        # @param [Proc] block the block that will be called.
        # @yield [Hash, *args] the environment hash, plus optional arguments.
        # @yieldreturn [Hash] the block MUST return the environment hash.
        def after(name, &block)
          after_hooks[name] ||= []
          after_hooks[name].push(block)
        end

        # Load a custom engine from a file or HTTP URI.
        # The latest engine from the file will be returned.
        #
        # @param [String] uri the URI string of the file location.
        def load(uri)
          logger.info "Loading #{uri.inspect}"
          case URI.parse(uri.to_s)
          when URI::HTTP, URI::HTTPS
            tempfile = Tempfile.new(["g5k-campaign-engine-", ".rb"])
            tempfile.puts RestClient.get(uri)
            tempfile.close
            klass = tempfile.path
          else
            klass = File.expand_path(uri)
          end

          require klass

          engine = subclasses.last
          engine.set :chdir, File.dirname(klass)
          engine
        end

        def inherited(klass)
          subclasses.push(klass)
        end

        def subclasses
          @@subclasses ||= [Engine]
        end

        def deep_copy(object) #:nodoc:
          case object
          when Hash
            h = {}
            object.each{|k,v|
              h[k] = deep_copy(v)
            }
            h
          else
            object.dup rescue object
          end
        end

        # @return [Hash<Symbol, Proc>] the hash of registered before_* hooks.
        def before_hooks
          @before_hooks ||= deep_copy(parent(:before_hooks) || {})
        end

        # @return [Hash<Symbol, Proc>] the hash of registered after_* hooks.
        def after_hooks
          @after_hooks ||= deep_copy(parent(:after_hooks) || {})
        end

        # @return [Hash<Symbol, Proc>] the hash of registered on_* hooks.
        def on_hooks
          @on_hooks ||= deep_copy(parent(:on_hooks) || {})
        end

        # Finds the first SSH key that has both public and private parts in the <tt>~/.ssh</tt> directory.
        # @return [Array<String,String>] the public_key_path and private_key_path if <tt>key_type</tt> is <tt>nil</tt>.
        # @return [String] the public key if <tt>key_type=:public</tt>, or the private key if <tt>key_type=:private</tt>.
        def keychain(key_type = nil)
          public_key = nil
          private_key = nil
          Dir[File.expand_path("~/.ssh/*.pub")].each do |file|
            public_key = file
            private_key = File.join(
              File.dirname(public_key),
              File.basename(public_key, ".pub")
            )
            if File.exist?(private_key) && File.readable?(private_key)
              break
            else
              private_key = nil
            end
          end
          case key_type
          when :public
            public_key
          when :private
            private_key
          else
            [public_key, private_key]
          end
        end
      end

      # The <tt>Restfully::Session</tt> object.
      attr_accessor :connection

      # Defaults
      set :logger, Logger.new(STDERR)
      set :data_logger, Logger.new(STDERR)
      set :user, ENV['USER']
      set :site, "rennes"
      set :environment, "squeeze-x64-base"
      set :resources, "nodes=1"
      set :walltime, 3600
      set :no_deploy, false
      set :no_submit, false
      set :no_install, false
      set :no_execute, false
      set :no_cancel, false
      set :no_cleanup, false
      set :notifications, []

      set :public_key, keychain(:public)
      set :private_key, keychain(:private)
      set :deployment_max_attempts, 1
      set :deployment_min_threshold, 100/100
      set :deployment_timeout, 15*60
      set :submission_timeout, 5*60
      set :ssh_max_attempts, 3
      set :chdir, Dir.pwd
      set :polling_frequency, 10


      # Initialize the experiment engine.
      # @param [Restfully::Session] connection a Restfully::Session, correctly configured
      # @param [Hash] options a hash of options
      # @see USER_ATTRIBUTES
      # @note the <tt>options</tt> hash can contain any of the USER_ATTRIBUTES, which will overwrite the defaults set by the engine.
      def initialize(connection, options = {})
        USER_ATTRIBUTES.each do |uattr|
          self.class.defaults[uattr] = options[uattr] || options[uattr.to_s] || self.class.defaults[uattr]
        end

        # Do not allow direct modification of defaults after initialization.
        # Users should only change the<tt>env</tt> hash that is passed to every hook, if needed.
        self.class.defaults.freeze

        @connection = connection
        @mutex = Mutex.new
      end


      # Run the experiment.
      # @return [Array<String>] the array of nodes FQDN
      def run!
        reset!

        # set up environment hash
        env = self.class.defaults.dup

        nodes = []

        %w{INT TERM}.each do |signal|
          Signal.trap( signal ) do
            logger.fatal "Received #{signal.inspect} signal. Exiting..."
            exit(1)
          end
        end

        logger.debug self.inspect


        change_dir do

          env = execute_with_hooks(:reserve!, env) do |env|
            env[:nodes] = env[:job]['assigned_nodes']

            env = execute_with_hooks(:deploy!, env) do |env|
              env[:nodes] = env[:deployment]['result'].reject{ |k,v|
                v['state'] != 'OK'
              }.keys.sort

              synchronize {
                nodes.push(env[:nodes]).flatten!
              }

              #FIXME Add vlan managment (data here http://sebian.yasaw.net/pub/debug.txt )
              # Une fois que les noeuds sont déployés (vlan de prod, avec fqdn de prod)
              # il faut injecter les fqdn kavlan.
              # if defined? env[:job]['resources_by_type']['vlans'][0]
              #   kavlan = []
              #   env[:nodes].each do |convert|
              #     kavlan << "#{convert.split('.')[0]}-kavlan-#{env[:job]['resources_by_type']['vlans'][0]}.#{env[:site]}.grid5000.fr"
              #   end
              #   env[:nodes] = kavlan.dup
              # end

              env = execute_with_hooks(:install!, env) unless env[:no_install]
              env = execute_with_hooks(:execute!, env) unless env[:no_execute]

              unless env[:no_cleanup]
                # Only cleans up the deployment
                logger.info "Launching cleanup procedure (pass the --no-cleanup flag to avoid this)..."
                env = execute_with_hooks(:cleanup!, env, nil, env[:deployment])
              end

            end # :deploy!

            unless env[:no_cleanup]
              # Only cleans up the job
              logger.info "Launching cleanup procedure (pass the --no-cleanup flag to avoid this)..."
              env = execute_with_hooks(:cleanup!, env, env[:job], nil)
            end
          end # :reserve!

        end # change_dir

        # Return the valid nodes at the end of the run
        nodes
      rescue Exception => e
        logger.error "Received exception: #{e.class.name} - #{e.message}"
        e.backtrace.each {|b| logger.debug b}
        unless env[:no_cancel]
          logger.info "Launching cancellation procedure (pass --no-cancel flag to avoid this)..."
          execute_with_hooks(:cancel!, env)
        end
        nil
      end


      # Reset some variables.
      def reset!
        synchronize {
          @parallel = Parallel.new
          @jobs = []
          @deployments = []
        }
      end


      # Reserve the specified resources for the specified walltime or attempts to reuse existing job if <tt>env[:no_submit]==true</tt>.
      #
      # @param [Hash, Proc] env the environment hash, and an optional block to call if the reservation succeeds.
      # @yield [Hash, Proc] the environment hash with the new job available in <tt>env[:job]</tt> if successful.
      # @return [Hash, nil] the environment hash with the new job available in <tt>env[:job]</tt> if successful, otherwise <tt>nil</tt>.
      #
      # If you want to customize what is done on the reservation phase, you should register a <tt>on(:reserve!)</tt> hook as follows:
      #   on :reserve! do |env, block|
      #     # Do whatever crazy things you want, change the environment options if needed.
      #     # ...
      #     # Reuse the original reserve! method when you want to submit a job (can be called multiple times).
      #     reserve!(env, &block)
      #     # some other things...
      #     env
      #   end
      #
      # This method is thread-safe.
      #
      def reserve!(env = {}, &block)
        logger.info "[#{env[:site]}] Launching job [no-submit=#{env[:no_submit].inspect}]..."
        if env[:no_submit]
          # Try to reuse the last job running with the same name
          # FIXME: It should test for the same :resources attribute,
          # but OAR api does not provide that at the moment...
          job = connection.root.sites[env[:site].to_sym].jobs(
#            :reload => true # Fixing problem when reusing job
          ).find{|j|
            # j['name'] == env[:name] &&
            j['state'] == 'running' &&
            # j['user_uid'] == env[:user]
            j['uid'] == env[:uid]
          }
        else
          payload = {
            :command => "sleep #{env[:walltime]}",
            :name => env[:name],
            :types => ["deploy"],
            :properties => env[:properties],
          }.merge(env.reject{ |k,v| !valid_job_key?(k) })
          payload[:types] = ["deploy"]  if not env[:environment].nil?
          payload[:resources] = [
            env[:resources], "walltime=#{oar_walltime(env)}"
          ].join(",")
          job = connection.root.sites[env[:site].to_sym].jobs.submit(payload)
        end

        if job.nil?
          if env[:no_submit]
            env[:no_submit] = false
            # if a new job has to be submitted,
            # a new deployment must also be submitted
            env[:no_deploy] = false
            reserve!(env, &block)
          else
            logger.error "[#{env[:site]}] Cannot get a job"
            nil
          end
        else
          sleep 1
          job.reload
          synchronize { @jobs.push(job) }
          #logger.info "[#{env[:site]}] Got the following job: #{job.inspect}"
          logger.info "[#{env[:site]}] Got the following job: #{job['uid']}"
          data_logger.info job
          logger.info "[#{env[:site]}] Waiting for state=running for job ##{job['uid']} (expected start time=\"#{Time.at(job['scheduled_at']) rescue "unknown"}\")..."

          Timeout.timeout(env[:submission_timeout]) do
            while job.reload['state'] != 'running'
              sleep env[:polling_frequency]
            end
          end

          #logger.info "[#{env[:site]}] Job is running: #{job.inspect}"
          logger.info "[#{env[:site]}] Job is running:"
          data_logger.info job
    
          env[:job] = job
          yield env if block
          env
        end
      end

      # Deploy the specified <tt>env[:nodes]</tt> with the specified <tt>env[:environment]</tt> or attempts to reuse an existing deployment (on the same nodes requested by the same user) if <tt>env[:no_deploy]==true</tt>.
      #
      # @param [Hash] env the environment hash, and an optional block to call if the deployment succeeds.
      # @yield [Hash, Proc] the environment hash with the new deployment available in <tt>env[:deployment]</tt> if successful.
      # @return [Hash, nil] the environment hash with the new deployment available in <tt>env[:deployment]</tt> if successful, otherwise <tt>nil</tt>.
      #
      # If you want to customize what is done on the deployment phase, you should register a <tt>on(:deploy!)</tt> hook as follows:
      #   on :deploy! do |env, block|
      #     # Do whatever crazy things you want
      #     # ...
      #     # Reuse the original deploy! method when you want to submit a deployment (can be called multiple times).
      #     deploy!(env, &block)
      #     # some other things...
      #     env
      #   end
      #
      # This method is thread-safe.
      #
      def deploy!(env = {})
        env[:remaining_attempts] ||= env[:deployment_max_attempts]

        data_logger.info "nodes: "
        data_logger.info env[:nodes]

        env[:nodes] = [env[:nodes]].flatten.sort
        logger.info "[#{env[:site]}] Launching deployment [no-deploy=#{env[:no_deploy].inspect}]..."
        if env[:no_deploy]
          # attempts to find the latest deployment on the same nodes
          deployment = connection.root.sites[env[:site].to_sym].deployments(
            :reload => true
          ).find{ |d|
            d['nodes'].sort == env[:nodes] &&
            d['user_uid'] == env[:user] &&
            d['created_at'] >= env[:job]['started_at'] &&
            d['created_at'] < env[:job]['started_at']+env[:walltime]
          }
        else
          if env[:remaining_attempts] > 0
            if env[:remaining_attempts] < env[:deployment_max_attempts]
              logger.info "Retrying deployment..."
            end
            #FIXME Add vlan managment (data here http://sebian.yasaw.net/pub/debug.txt )
            # On passe le numéro de vlan si il existe, si non vlan = nil (bien géré par l'api)
            vlan = env[:job]['resources_by_type']['vlans'][0] if defined? env[:job]['resources_by_type']['vlans'][0]
            logger.info "Got the following key specification: #{key_for_deployment(env)}"
            env[:remaining_attempts] -= 1
            deployment = connection.root.sites[env[:site].to_sym].deployments.submit({
              :nodes => env[:nodes],
              :notifications => env[:notifications],
              :vlan => vlan,
              :environment => env[:environment],
              :key => key_for_deployment(env)
            }.merge(env.reject{ |k,v| !valid_deployment_key?(k) }))
          else
            logger.info "[#{env[:site]}] Hit the maximum number of retries. Halting."
            deployment = nil
          end
        end

        if deployment.nil?
          # if no valid deployment can be found without deploying, go through the normal path
          if env[:no_deploy]
            env[:no_deploy] = false
            deploy!(env)
          else
            logger.error "[#{env[:site]}] Cannot submit the deployment."
            nil
          end
        else
          deployment.reload
          synchronize { @deployments.push(deployment) }

          logger.info "[#{env[:site]}] Got the following deployment: #{deployment['uid']}"
          data_logger.info deployment
          logger.info "[#{env[:site]}] Waiting for termination of deployment ##{deployment['uid']} in #{deployment.parent['uid']}..."

          Timeout.timeout(env[:deployment_timeout]) do
            while deployment.reload['status'] == 'processing'
              sleep env[:polling_frequency]
            end
          end

          if deployment_ok?(deployment, env)
            logger.info "[#{env[:site]}] Deployment is terminated:"
            data_logger.info deployment
            env[:deployment] = deployment
            yield env if block_given?
            env
          else
            # Retry
            synchronize { @deployments.delete(deployment) }
            logger.error "[#{env[:site]}] Deployment failed:"
            data_logger.info "Deployment failed"
            data_logger.info deployment
            deploy!(env) unless env[:no_deploy]
          end
        end
      end


      # This method performs installation commands on the nodes.
      # @param [Hash] env the environment hash.
      def install!(env)
        logger.warn "Your engine does not overwrite the :install! method. Nothing will be installed on #{env[:nodes].inspect}."
        env
      end

      # This method should contain the "logic" of the campaign, once everything is setup.
      # @param [Hash] env the environment hash.
      def execute!(env)
        logger.warn "Your engine does not overwrite the :execute! method. Nothing will be executed on #{env[:nodes].inspect}."
        env
      end


      # Cleans up the current experiment job and deployment, if any.
      # @param [Hash] env the environment hash.
      def cancel!(env)
        logger.warn "Received cancellation signal."
        cleanup!(env)
        env
      end

      def cleanup!(env, job = nil, deployment = nil)
        synchronize {
          if job.nil? && deployment.nil?
            logger.info "Cleaning up all jobs and deployments..."
            @deployments.each{ |d| d.delete }.clear
            @jobs.each{ |j| j.delete }.clear
          else
            unless deployment.nil?
              logger.info "Cleaning up deployment##{deployment['uid']}..."
              @deployments.delete(deployment) && deployment.delete
            end
            unless job.nil?
              logger.info "Cleaning up job##{job['uid']}..."
              @jobs.delete(job) && job.delete
            end
          end
        }
        env
      end

      # Synchronization method.
      def synchronize(&block)
        @mutex.synchronize(&block)
      end


      # Primite that returns a new Parallel object.
      # <tt>Parallel#loop!</tt> must be explicitly called to wait for the threads within the <tt>Parallel</tt> object.
      #
      # @param [Hash] options a hash of additional options to pass.
      #
      # If option <tt>:ignore_thread_exceptions</tt> is given and true, then standard exceptions (including timeouts) that occur in one of the threads will be ignored (only an error log will be displayed). This is useful if you are doing multi-site campaigns.
      def parallel(options = {}, &block)
        p = Parallel.new({:logger => logger}.merge(options))
        yield p if block_given?
        p
      end

      # Setup an SSH connection as <tt>username</tt> to <tt>fqdn</tt>.
      # @param [String] fqdn the fully qualified domain name of the host to connect to.
      # @param [String] username the login to use to connect to the host.
      # @param [Hash] options a hash of additional options to pass.
      # @yield [Net::SSH::Connection::Session] ssh a SSH handler.
      #
      # By default, the SSH connection will be retried at most <tt>ssh_max_attempts</tt> times if the host is unreachable. You can overwrite that default locally by passing a different <tt>ssh_max_attempts</tt> option.
      # Same for <tt>:timeout</tt> and <tt>:keys</tt> options.
      #
      # If option <tt>:multi</tt> is given and true, then an instance of Net::SSH::Multi::Session is yielded. See <http://net-ssh.github.com/multi/v1/api/index.html> for more information.
      def ssh(fqdn, username, options = {}, &block)
        raise ArgumentError, "You MUST provide a block when calling #ssh" if block.nil?
        options[:timeout] ||= 10
        if options.has_key?(:password)
          options[:auth_methods] ||= ['keyboard-interactive']
        else
          options[:keys] ||= [private_key].compact
        end
        max_attempts = options[:ssh_max_attempts] || ssh_max_attempts
        logger.info "SSHing to #{username}@#{fqdn.inspect}..."
        attempts = 0
        begin
          attempts += 1
          if options[:multi]
            Net::SSH::Multi.start(
              :concurrent_connections => (
                options[:concurrent_connections] || 10
              )
            ) do |session|
              session.via gateway, user unless gateway.nil?
              fqdn.each {|h| session.use "#{username}@#{h}"}
              block.call(session)
            end
          else
            if gateway
              gateway_handler = Net::SSH::Gateway.new(gateway, user, options)
              gateway_handler.ssh(fqdn, username, options, &block)
              gateway_handler.shutdown!
            else
              Net::SSH.start(fqdn, username, options, &block)
            end
          end
        rescue Errno::EHOSTUNREACH => e
          if attempts <= max_attempts
            logger.info "No route to host #{fqdn}. Retrying in 5 secs..."
            sleep 5
            retry
          else
            logger.info "No route to host #{fqdn}. Won't retry."
            raise e
          end
        end
      end


      def inspect
        s = "#<#{self.class.name}:0x#{self.object_id.to_s(16)}"
        USER_ATTRIBUTES.sort_by{|u| u.to_s}.each {|uattr|
          next if [:logger].include?(uattr)
          s << " @#{uattr}=#{send(uattr).inspect}"
        }
        s << ">"
      end


      # Returns the number of nodes that correspond to the specified state criteria, for each site requested.
      # @param [Hash] options the options to filter the result with.
      # @option options [String,Array] :hard (:alive) a symbol or array of symbols specifying the hardware status(es) that must be matched by the nodes to be counted.
      # @option options [String,Array] :soft ([:free, :besteffort]) a symbol or array of symbols specifying the system status(es) that must be matched by the nodes to be counted.
      # @option options [String,Array] :in (all) a symbol or array of symbols specifying the sites of interest.
      #
      # @example How many nodes are alive && (free || besteffort) in rennes and nancy?
      #   how_many?(:hard => :alive, :soft => [:free, :besteffort], :in => [:rennes, :nancy]) # => {:rennes => 40, :nancy => 23}
      #
      def how_many?(options = {})
        options = {:hard => :alive, :soft => [:free, :besteffort]}.merge(options)
        count = {}

        sites = [options[:in]].flatten.compact.map(&:to_s)
        hard_state = [options[:hard]].flatten.compact.map(&:to_s)
        soft_state = [options[:soft]].flatten.compact.map(&:to_s)

        connection.root.sites.each do |site|
          next if !sites.empty? && !sites.include?(site['uid'])
          count[site['uid'].to_sym] = site.status.count do |ns|
            hard_state.include?(ns['hardware_state']) &&
            soft_state.include?(ns['system_state'])
          end
        end

        count
      end

      # Send a notification.
      # @param [String] message the message to send.
      # @param [Array] to a list of notification URIs.
      #
      # By default, it sends to the default notifications array.
      def notify(message, to = nil)
        to ||= notifications
        return true if to.nil? || to.empty?
        connection.post("/sid/notifications", {:to => [to].flatten, :body => message})
      rescue Exception => e
        logger.warn "Cannot send notification: #{e.class.name} - #{e.message}"
        false
      end

      protected

      # Change working directory if <tt>chdir</tt> is set.
      def change_dir(&block)
        if chdir
          logger.debug "In #{chdir}"
          Dir.chdir(chdir, &block)
        else
          block.call
        end
      end

      # Used to filter out keys from environment hash when submitting a deployment.
      # @return [Boolean] true if <tt>k</tt> is a valid deployment attribute. Otherwise false.
      def valid_deployment_key?(k)
        [:key, :environment, :notifications, :nodes, :version, :block_device, :partition_number, :vlan, :reformat_tmp, :disable_disk_partitioning, :disable_bootloader_install, :ignore_nodes_deploying].include?(k)
      end

      # Used to filter out keys from environment hash when submitting a job.
      # @return [Boolean] true if <tt>k</tt> is a valid deployment attribute. Otherwise false.
      def valid_job_key?(k)
        [:resources, :reservation, :command, :directory, :properties, :types, :queue, :name, :project, :notifications].include?(k)
      end

      # Returns true if the deployment is not in an error state
      # AND the number of correctly deployed nodes is greater or
      # equal than <tt>env[:deployment_min_threshold]</tt> variable
      def deployment_ok?(deployment, env = {})
        return false if deployment.nil?
        return false if ["canceled", "error"].include? deployment['status']
        nodes_ok = deployment['result'].values.count{|v|
          v['state'] == 'OK'
        } rescue 0
        nodes_ok.to_f/deployment['nodes'].length >= env[:deployment_min_threshold]
      end

      # Run before_* hooks
      def run_before_hooks(name, env, *args)
        (self.class.before_hooks[name] || []).each do |hook|
          env = execute_hook("before_#{name}", hook, env, *args)
        end
        env
      end

      # Run on_* hooks
      def run_on_hooks(name, env, *args, &block)
        if (self.class.on_hooks[name] || []).empty?
          env = send(name, env, *args, &block) || raise(HookError, "Execution of #{name} failed.")
        else
          (self.class.on_hooks[name] || []).each do |hook|
            env = execute_hook("on_#{name}", hook, env, *args, &block)
          end
        end
        env
      end

      # Run after_* hooks
      def run_after_hooks(name, env, *args)
        (self.class.after_hooks[name] || []).each do |hook|
          env = execute_hook("after_#{name}", hook, env, *args)
        end
        env
      end

      # Execute a method by wrapping it within before and after hooks
      # If on_* hooks are registered for the method, it *won't* execute the native method. The user has to call it explictely.
      def execute_with_hooks(method, env, *args, &block)
        env = run_before_hooks(method, env, *args)
        if block
          env = run_on_hooks(method, env, *args) { |env, *args|
            # Run after_* hooks before calling the block, or they will be called AFTER the end of the block, which might issue #install! or #execute! commands.
            run_after_hooks(method, env, *args)
            block.call(env, *args)
          }
        else
          env = run_on_hooks(method, env, *args, &block)
          env = run_after_hooks(method, env, *args)
        end
      end

      # Execute a hook
      #
      # @raise [HookError] if the hook does not return true.
      def execute_hook(name, hook, env, *args, &block)
        env = instance_exec(env, *args.push(block), &hook) || raise(HookError, "Execution of #{name} hook failed.")
      end

      # Returns the walltime in the format supported by OAR
      def oar_walltime(env)
        walltime = env[:walltime]
        hours = (walltime/3600).floor
        minutes = ((walltime-(hours*3600))/60).floor
        seconds = walltime-hours*3600-minutes*60
        "%02d:%02d:%02d" % [hours, minutes, seconds]
      end

      # Returns a valid key for the deployment
      # If the public_key points to a file, read it
      # If the public_key is a URI, fetch it
      def key_for_deployment(env)
        uri = URI.parse(env[:public_key])
        case uri
        when URI::HTTP, URI::HTTPS
          connection.get(uri.to_s).body
        else
          logger.info "reading public key file: #{env[:public_key]}"
          File.read(env[:public_key])
        end
      end

    end # class Engine


  end # module Campaign
end # module Grid5000
