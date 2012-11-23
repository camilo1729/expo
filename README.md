Expo: Experiment Engine for Distributed Platforms
=================================================

**Homepage**: [http://expo.gforge.inria.fr/](http://expo.gforge.inria.fr)
 
**Git**:      [https://github.com/camilo1729/expo](https://github.com/camilo1729/expo) 

**SNV**:      [svn://scm.gforge.inria.fr/svnroot/expo/](svn checkout svn://scm.gforge.inria.fr/svnroot/expo/)

**Authors**:   Cristian Ruiz, Brice Videau, Olivier Richard.

**Latest Version**: 0.4a (Experimental)




Synopsis
--------

Expo is an experiment engine for distributed platforms. It aims at simplifying the experimental process on such platforms.

* [Feature List](#features)
* [Using Expo with Grid5000 API](#GridAPI)
* [Installation](#install)
* [Getting Started with Expo Interactive Console](#Console)
* [Contact](#contact)
* [Related Publications](#publications)



<a name="features"></a>

## Feature List

Expo proposes a DSL (Domain Specific Language) derived from Ruby and adapted to the management of experiment. It is based on several abstractions like tasks, tasksets, resources and resourcesets. These abstractions, combined with the expressiveness of ruby allows for concise yet powerful experiment descriptions.

Expo is built from two distinct parts: a client and a server. 
The client is responsible for translating the Expo script into commands the server will execute. 
This dichotomy can help save a lot of time. 
Indeed, an experiment script containing an error might abort the client, but the commands already launched on the server, and the results gathered are not lost.
Native logging and archiving capabilities

In order to maximize the reproducibility and the analysis of experiments the Expo server comes with native logging capabilities. 
Standard outputs, inputs and errors are logged into memory and files. 
Those data can then be archived on disk, for longer keeping or in order to free memory. 
Start date, end date, status of each commands are also logged.

At the moment Expo interacts with Planetlab and Grid5000 testbeds. 
For interacting with Grid5000, Expo uses {http://g5k-campaign.gforge.inria.fr/ Grid5000 campaign} 
in order to get access to the {http://www.grid5000.fr/mediawiki/index.php/API Grid5000 API} 
as well as the process of reserving and deploying. 

<a name="GridAPI"></a>

## Using Expo with Grid5000

Expo helps you to run experiments on Grid5000. With Expo you can easily:

1. Reserve nodes.
2. Deploy environments.
3. Do whatever you want with the reserved nodes.

To run the simplest experiments it will be sufficient just to understand the examples presented below. However, in order to happily use all the Expo functionality you are recommended to have at least basic knowledge of {http://www.grid5000.fr/mediawiki/index.php/API Grid5000 API} and such tools as {http://oar.imag.fr OAR}, {http://kadeploy3.gforge.inria.fr/ Kadeploy} and {http://taktuk.gforge.inria.fr/ Taktuk}.


<a name="install"></a>

## Installing Expo 

Expo can be run inside and outside Grid5000. For the following examples Expo is going to be installed and run inside Grid5000, from one of the chosen frontends.
As everything is going to be installed on the frontend, we need to configure gem in order to install the Expo dependencies on the user's home directory.
Which is achieved executing:

    export GEM_HOME=~/.gem/ 

The new version of Expo uses the {http://github.com/crohr/restfully Restfully} ruby gem to reserve and deploy the nodes using the Grid5000 API.

If the Resfully gem is not yet installed:

	gem install restfully

After installing the package a configuration file has to be created. This configuration file is used inside Grid5000. 
Outside the user and password have to be specified.

	$ echo 'base_uri: https://api.grid5000.fr/2.1/grid5000' > ~/.restfully/api.grid5000.fr.yml 
	$ chmod 600 ~/.restfully/api.grid5000.fr.yml

Expo depends on termios so it has to be installed before running Expo, install it with gem

	gem install termios

One of the main functionalities of Expo is to offer an interactive console where the user can set up his/her experiment.
Because the set up of en experiment is an erro-prone task this interactive console comes in handy. 
This console is based in {http://pryrepl.org Pry} which offer several functionalities as syntax highlighting,
Command shell integration, allow significant user customization. To install it.

	gem install pry

After that, just check out the repository through anonymous access with the following command(s).

	svn checkout --username anonsvn https://scm.gforge.inria.fr/svn/expo/

The password is: anonsvn.

or its GitHub counterpart.
       
    git clone https://github.com/camilo1729/expo.git

<a name="Console"></a>

## Getting Started with Expo interactive Console

### First try

The first thing to do is to familiarize with Expo functionalities and syntax, to do so run expo:

    $./expo

You will get the following output.

    ruby 1.8.7 (2010-08-16 patchlevel 302) [x86_64-linux]
    Welcome to Expo Interactive Mode
    All the libraries have been loaded
    Opening Experiment
    Preparing resource container $all
    Connecting to the Grid5000 API

    Expo Console > 

After the initialization of the Console, a connection to the API is created and is it saved in the global variable "@connection"
You have to create a reservation object using this connection.

    Expo Console > reserv=ExpoEngine::new(@connection)

The object just created has some default parameters for the reservation that can be seen with:

    Expo Console > reserv.defaults
    => [[:environment, nil],
    [:resources, "nodes=1"],
    [:site, "rennes"],
    [:types, ["allow_classic_ssh"]],
    [:walltime, 3600]]
    Expo Console > 

A reservation can be run with those parameters by doing:

    Expo Console > reserv.run!

And will produce the following output:
    
    2012-02-18 15:39:36 +0100 [DEBUG] In /home/cruizsanabria/Repositories/git/expo/bin 
    2012-02-18 15:39:36 +0100 [INFO] [ Expo Engine Grid5000 API ] Asking for Resources 
    2012-02-18 15:39:36 +0100 [INFO] [ Expo Engine Grid5000 API ] Number of nodes to reserve in site: grenoble => nodes=1 
    2012-02-18 15:39:36 +0100 [INFO] [grenoble] Launching job [no-submit=false]... 
    2012-02-18 15:39:47 +0100 [INFO] [grenoble] Got the following job: 1391958 

You have to wait till the reservation take place:

    2012-02-18 15:42:53 +0100 [INFO] [grenoble] Job is running:

The next step is to take a look at the variable $all automatically filled with the reserved resources description.
It looks something like this:

    Expo Console > $all
    => #<Expo::ResourceSet:0x7f39774d8f20
    @properties={},
    @resource_files={},
    @resources=
	[#<Expo::ResourceSet:0x7f397712e960
    	@properties=
		{:alias=>"borderline",
      		:gateway=>"frontend.bordeaux.grid5000.fr",
      		:site=>"bordeaux",
      		:name=>"ExpoEngine",
      		:id=>948835},
    	@resource_files={},
    	@resources=
		[#<Expo::Resource:0x7f397712e708
      	 	@properties=
			{:gateway=>"frontend.bordeaux.grid5000.fr",
         		:site=>"bordeaux",
         		:name=>"borderline-9.bordeaux.grid5000.fr"},
       		@type=:node>],
    		@type=:resource_set>],
    @type=:resource_set>

This $all variable is an object from the Class "Resource_set",
which helps the user to keep track of the resources reserved with its hierarchical structure
and some important related information. This Class has some special methods and operators.
For example in order to know how many resources were reserved:

    Expo Console > $all.length
    => 1

We see that resources are grouped by cluster and have some properties like the number of the job that generated it, 
the site , the gateway ( Important for executing commands with TakTuk), etc.
We are going to see more characteristic of this "Resource_Set" Class with more examples.
What if we want to execute something on this resource reserved, it is easy with Expo.
Execute the command "hostname" on a remote host:

    Expo Console > task $all.first, "hostname"
    borderline-9.bordeaux.grid5000.fr
    2012-11-18 18:54:41 +0100 [INFO] [ Sequential Task:0 ]  [ Executed ]   hostname  
    2012-11-18 18:54:41 +0100 [INFO] [ Sequential Task:0 ]  [ On Node ]  borderline-9.bordeaux.grid5000.fr  
    2012-11-18 18:54:41 +0100 [INFO] [ Sequential Task:0 ]  [ Elapsed Time ] 0.00496 secs 
    => [0,
    [{"stdout"=>"borderline-9.bordeaux.grid5000.fr\n",
    "end_time"=>Sun Nov 18 18:54:41 +0100 2012,
    "host_name"=>"borderline-9.bordeaux.grid5000.fr",
    "stderr"=>"",
    "rank"=>"1",
    "status"=>"0",
    "command_line"=>"cd . ; hostname ",
    "start_time"=>Sun Nov 18 18:54:41 +0100 2012}]]

This command returns the id of the task executed and 
a special Hash that is called "ExpoResult" containing information about the execution such as: start time, end time, host used, command executed, etc.
We can keep this information in a variable doing:

    Expo Console > id, res =task $all.first, "hostname"

And explore each one of the values.

    Expo Console > res[0]['stdout']
    => "borderline-9.bordeaux.grid5000.fr"

As well as calculating the time it took to execute the command:
   
    Expo Console > res[0].duration
    => 0.00495

If we want to free the resources we execute:

    Expo Console > reserv.stop!
    2012-11-18 19:14:01 +0100 [INFO] Cleaning up all jobs and deployments... 
    => #<Expo::ResourceSet:0x7f39774cca18
    @properties={},
    @resource_files={},
    @resources=[],
    @type=:resource_set>

This will clean the environment and will delete any job submitted.
All the activity is logged into two files: 

* Expo_log_(time stamp).log
* Expo_data_log_(time stamp).log

The first one logs information about the principal events and the second one keeps track of all the data structures produced.
It is a more detailed log.

Now that we know the basics of Expo let's move further.

### Simple example with several machines.

Let's use several machines, and see what Expo has to offer.
So go into the expo console and create the reservation object as seen in the previous section.
Here again:

     Expo Console > reserv=ExpoEngine::new(@connection)
     
And now let's change some parameters of the reservation, choose several machines in bordeaux site:

    Expo Console > reserv.site=["bordeaux"]
    => ["bordeaux"]
    Expo Console > reserv.resources=["nodes=10"]
    => ["nodes=10"]
    Expo Console > reserv.walltime=600
    => 600

We run the reservation:

    Expo Console > reserv.run!
    2012-11-18 19:42:35 +0100 [DEBUG] In /home/cruizsanabria/Repositories/git/expo/bin 
    2012-11-18 19:42:35 +0100 [INFO] [ Expo Engine Grid5000 API ] Asking for Resources 
    2012-11-18 19:42:35 +0100 [INFO] [ Expo Engine Grid5000 API ] Number of nodes to reserve in site: bordeaux => nodes=10 
    2012-11-18 19:42:35 +0100 [INFO] [bordeaux] Launching job [no-submit=false]... 

After waiting few minutes we got the job.
      
     2012-11-18 19:42:45 +0100 [INFO] [bordeaux] Got the following job: 948839 
     2012-11-18 19:42:55 +0100 [INFO] [bordeaux] Job is running: 

If we take a look at the Resource_set it should look something like this:

     => #<Expo::ResourceSet:0x7f1cbd9fdf40
     @properties={},
     @resource_files={},
     @resources=
	[#<Expo::ResourceSet:0x7f1cbb0f6228
		@properties=
			{:alias=>"borderline",
      			:gateway=>"frontend.bordeaux.grid5000.fr",
      			:site=>"bordeaux",
      			:name=>"ExpoEngine",
      			:id=>948839},
    		@resource_files={},
    		@resources=
     	[#<Expo::Resource:0x7f1cbb0f5940
		@properties=
			{:gateway=>"frontend.bordeaux.grid5000.fr",
         		:site=>"bordeaux",
         		:name=>"borderline-1.bordeaux.grid5000.fr"},
       		@type=:node>,
      	#<Expo::Resource:0x7f1cbb0f5828
		@properties=
			{:gateway=>"frontend.bordeaux.grid5000.fr",
         		:site=>"bordeaux",
         		:name=>"borderline-2.bordeaux.grid5000.fr"},
       		@type=:node>,
      	#<Expo::Resource:0x7f1cbb0f51e8
		@properties=
			{:gateway=>"frontend.bordeaux.grid5000.fr",
         		:site=>"bordeaux",
         		:name=>"borderline-3.bordeaux.grid5000.fr"},
       		
The output was chopped off because its long. Here we got resources from two different clusters:

we can print the hostnames of the nodes per cluster:

     Expo Console > $all["borderline"].each { |node| puts node.name}
     borderline-1.bordeaux.grid5000.fr
     borderline-2.bordeaux.grid5000.fr
     borderline-3.bordeaux.grid5000.fr
     => nil

For the other cluster:

     Expo Console > $all["bordereau"].each { |node| puts node.name}
     bordereau-9.bordeaux.grid5000.fr
     bordereau-84.bordeaux.grid5000.fr
     bordereau-85.bordeaux.grid5000.fr
     bordereau-86.bordeaux.grid5000.fr
     bordereau-90.bordeaux.grid5000.fr
     bordereau-91.bordeaux.grid5000.fr
     bordereau-92.bordeaux.grid5000.fr

    
Therefore, we got 3 nodes in cluster "bordereau" and 7 in "borderline".
But well the interesting thing is to execute commands in those machines. 
We simply use ptask ( Paralle task).

    Expo Console > ptask $all, "hostname"
    bordereau-84.bordeaux.grid5000.fr
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ Executed ]   hostname
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ On Node ]  bordereau-84.bordeaux.grid5000.fr
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ Elapsed Time ] 0.0049 secs
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ Executed ]   hostname      
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ On Node ]  bordereau-92.bordeaux.grid5000.fr  
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ Elapsed Time ] 0.0047 secs 
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ Executed ]   hostname  
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ On Node ]  bordereau-85.bordeaux.grid5000.fr  
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ Elapsed Time ] 0.00468 secs 
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ Executed ]   hostname  
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ On Node ]  bordereau-86.bordeaux.grid5000.fr  
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ Elapsed Time ] 0.00462 secs 
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ Executed ]   hostname  
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ On Node ]  bordereau-90.bordeaux.grid5000.fr  
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ Elapsed Time ] 0.00508 secs 
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ Executed ]   hostname  
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ On Node ]  borderline-1.bordeaux.grid5000.fr  
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ Elapsed Time ] 0.00527 secs 
    2012-11-18 20:02:32 +0100 [INFO] [ Parallel Task:4 ]  [ Executed ]   hostname  


We can separate the resources of the two clusters and execute commands over them:

    Expo Console > id, res_bordereau =ptask $all["bordereau"], "hostname"
    Expo Console > id, res_borderline =ptask $all["borderline"], "hostname"

And compare their execution times:

    Expo Console > res_borderline.duration
    => 0.01201
    Expo Console > res_bordereau.duration
    => 0.00751

## Writing everthing into an Experiment Description File

The aim of the console is to try different commands that after will make part of an experiment.
Everything will be run without human intervention.
Let's write an experiment description file, which is mainly a ruby script but that has the support of
Expo's abstractions and Logging capabilities.


    reserv=ExpoEngine::new(@connection)
    reserv.site=["bordeaux","lille","luxembourg","nancy","sophia"]
    reserv.resources=["nodes=50","nodes=10","nodes=4","nodes=4","nodes=30"]
    reserv.name = "Expo Scalability"
    reserv.walltime=600

    reserv.run!

    sizes=[10,20,40,50,80,$all.length]

    $all.each_slice_array(sizes) do | nodes|
          
	  task_mon= Task::new("hostname",nodes," Monitoring #{nodes.length} nodes")
	  (10).times{
		
			id,res = task_mon.execute
			puts " #{res.length} : #{res.duration}"
  		
		}
    end

    reserv.stop!

The experiment here is about executing the linux command "hostname" over different sets of machines,
doing 10 tries per set of machines and after printing the results: how many machines have responded and the duration of the total execution.
In this file were introduced new functionalities, the method **each_slice_array**,     	
Which creates slices of sizes specified in the array.
These slices are used to try with different sets of machines 
which is quite done in testing scalability for a giving software.
The Object **Task** which is a cleaner way of executing parallel commands specially if
we do it several times, it gives more readability to the code
This object offers several possibilities and can be used in conjunction with other objects 
that are going to be presented later on.


## Expo Data

### List of Expo Engine reservation parameters

These are Grid5000 campaign specific.

* **:site => \["lille", "grenoble", ...\]**          reserve on specific sites
  **:site => "all"**                               reserve on all Grid5000 sites
  **:site => "any"**                               reserve on a site with the max number of available nodes
* **:resources => \["nodes=1", "nodes=5"\]**         reserve one node on the first site from :site, 5 nodes on the second site
  **:resources => \["cluster=2/nodes=3"\]**          reserve 3 nodes in 2 different clusters
  **:resources => \["{cluster='sagittaire' and memcpu=8192}/nodes=2"\]**   reserve 2 nodes with properties
* **:environment => {"env1" => 2}**                 deploy env1 environment on the first 2 nodes from resources array
  **:environment => {"env1" => 1, "env2" => 2}**    deploy env1 on the first node and env2 on the second and third nodes
* **:walltime => 1800**
* **:types => \["besteffort"\]**                      specify reservation type to "besteffort".
* **:name => "experiment_name"**                    the name of your experiment
* **:no_cleanup => false**                          specifies if the experiment will be deleted after the Expo returns
* **:deployment_max_attempts => 1**                 how many times we want to redeploy a node if the deployment fails
* **:submission_timeout => 5*60**                   for how long we wait for the reservation to be finished
* **:deployment_timeout => 15*60**                  for how long we wait for the deployment to be finished

The default values are:

	:site => \["rennes"\]
	:resources => \["nodes=1"\]
	:environment => nil
	:walltime => 3600
	:types => \["allow_classic_ssh"\]
	:no_cleanup => false
	:deployment_max_attempts => 1 >
	:submission_timeout => 5*60
	:deployment_timeout => 15*60


### Expo commands and global variables

* **$all** represents the general set of all reserved nodes.It is an object of ResourceSet class which contains the references to all reserved nodes represented by Resource objects. To check all the methods of ResourceSet and Resource classes see **lib/resourceset.rb**

* **task (node, command)** - execute **command** on **node** and wait till the command finishes its execution

* **atask (node, command)** - asyncronous task. Execute **command** on **node** and do not wait till the command finishes its execution
* **barrier** - wait for all asynchronous tasks to finish
* **ptask (location, targets, command)** - parallel task. Run **command** from **location** on all the **targets** in parallel, and wait till the command finishes.
* **copy (file, node, path={})** - copy **file** to **node** to the specified **path**. If path is not specified - copy to the default folder.
* **parallel_section( &block )** - executes sequential sections which are called in the **block** in parallel.
* **sequential_section( &block )** -- should be called from parallel_section; code from the block is executed sequentially.

<a name="contact"></a>


## Contact

cristian.ruiz@imag.fr or report a bug in {https://lists.gforge.inria.fr/mailman/listinfo/expo-users Expo Mailing List}

<a name="publications"></a>


## Related Publications

Brice Videau, Corinne Touati, and Olivier Richard. 
Toward an experiment engine for lightweight grids. In MetroGrid workshop : Metrology for Grid Networks. ACM publishing, Lyon, France, October 2007.
{file:docs/bib/Metro07.html bibtex}

Brice Videau and Olivier Richard. Expo : un moteur de conduite d'expériences pour plates-formes dédiées. In Conférence Française en Systèmes d'Exploitation (CFSE), Fribourg, Switzerland, February 2008. 
{file:docs/bib/CFSE6.html bibtex}

## Grid5000 tutorial
{file:docs/Grid5000_tutorial.md Expo and Kameleon}

## Changelog

- **Nov.19.12**: Released 0.4a experimental version for testing. The goal here is to get people testing Expo and know if it really makes easy the experimentation process.

- **Mar.8.10**: Added Ruby commands.	  




