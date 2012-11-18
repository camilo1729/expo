# @title Expo: Experiment engine for distributed platforms
# @author Cristian Ruiz
# Expo: Experiment Engine for Distributed Platforms

Expo is an experiment engine for distributed platforms. It aims at simplifying the experimental process on such platforms.

* [Feature List](#features)
* [Using Expo with Grid5000 API](#GridAPI)
* [Installation](#install)
* [Simple Example](#example)
* [More Examples](#more_examples)
* [Contact](#contact)
* [Related Publications](#publications)



<a name="features"></a>

## Feature List

Expo proposes a DSL (Domain Specific Language) derived from Ruby and adapted to the management of experiment. It is based on several abstractions like tasks, tasksets, resources and resourcesets. These abstractions, combined with the expressiveness of ruby allows for concise yet powerful experiment descriptions.
Decoupled client and server execution

Expo is built from two distinct parts: a client and a server. The client is responsible for translating the Expo script into commands the server will execute. This dichotomy can help save a lot of time. Indeed, an experiment script containing an error might abort the client, but the commands already launched on the server, and the results gathered are not lost.
Native logging and archiving capabilities

In order to maximise the reproducibility and the analysis of experiments the Expo server comes with native logging capabilities. Standard outputs, inputs and errors are logged into memory. Those data can then be archived on disk, for longer keeping or in order to free memory. Start date, end date, status of each commands are also logged.
Interface with resource brokers.


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
Which is achived executing:

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

After that, just check out the repository through anonymous access with the following command(s).

	svn checkout --username anonsvn https://scm.gforge.inria.fr/svn/expo/

The password is: anonsvn.

<a name="example"></a>

## Simple example 

In order to use Expo an experiment discription file has to be written. Because it is a simple example, this file can be written without problems but normaly for the definition of more complex experiments an {file:docs/Interactive.md interactive mode} is used, a console which allows the user to debug and get the description of the experiment ready.
First we are going to create our experiment description, which not differ to much from a ruby script.
	
	require 'g5k_api'
 	
	g5k_init(:site => ["lille", "grenoble"],:resources => ["nodes=2"],:walltime => 100) #Specifying the reservation

	g5k_run                     # run the reservation

	## $all: a Resource Set object that contains the resources reserved, this is executed in parallel.
	task1=Task::new("hostname",$all,"Test 1")   # Definition of the task to execute
	id, res = task1.execute			    # Execution of the task
	res.each { |r| puts r.duration }            # Printing out the duration of each execution.
	puts "mean : " + res.mean_duration.to_s	    # Printing out the mean duration of the tasks.



As it can be seen, an experiment specification can be divided into two parts:

1. Describe all your requirements (sites, nodes, environments, walltime, etc. ) and run reservation.

2. Do whatever you want with reserved nodes (using $all variable to address nodes and Expo’s DSL commands: task, atask, ptask, etc.)
In this example the class Task is use in order to execute the specific task in parallel over the resource Set.

we have to set up the ruby library:

	export RUBYLIB=/expo_home_path/lib/

Now we can execute the experiment executing :

	$/expo_home_path/bin/expo.rb simple_experiment.rb

<a name="more_examples"></a>

## More Examples

The examples above can be run with the same method previously shown.
### Using deployment

All you have to do to deploy an environment(s) on the reserved nodes is to list the environments and the number of nodes to deploy.
Let’s consider the following situation. You want to deploy “lenny-x64-base” environment on 1 node in Lyon and “squeeze-x64-base” on 1 node in Lyon as well as on 2 nodes in Grenoble. After the deployment is finished, you don’t want to close the experiment, but display all the nodes with deployed environment on them to be able to connect to them manually afterwards.

	require 'g5k_api'	
	
	g5k_init(
		:site => ["lyon", "grenoble"],
		:resources => ["nodes=2", "nodes=2"],
		:environment => {"lenny-x64-base" => 1, "squeeze-x64-base" => 3},
		:walltime => 1800,
		:no_cleanup => true                       # don't delete the experiment after the test is finished
		)
	g5k_run

	$all.each { |node|
		puts "Node: #{node.properties[:name]}; environment: #{node.properties[:environment]}"
	}

### Deprecated examples 
These examples though still run with Expo, they use oargridsub which use advance reservation that has to be avoided as much as possible.

	require 'expo_g5k' # Ruby library to interact with the Resource Manager	
	oargridsub :res => "toulouse:nodes=2,lille:nodes=2"  # Request of the resources
	 
	task1=Task::new("hostname",$all,"Test 1")   # Definition of the task to execute
	id, res = task1.execute			    # Execution of the task
	res.each { |r| puts r.duration }            # Printing out the duration of each execution.
	puts "mean : " + res.mean_duration.to_s	    # Printing out the mean duration of the tasks.

Parallel task example

	require 'expo_g5k'
	oargridsub :res => "grenoble:nodes=10,lille:nodes=10"
	ptask $all.gateway, $all, "date"
	id, res = ptask $all["grenoble"].gateway, $all["grenoble"], "sleep 1" # Use fo parallel task
	res.each { |r| puts r.duration }
	puts "mean : " + res.mean_duration.to_s

This simple program takes place in the Grid’5000 context. 20 resources are obtained from 2 different clusters : Grenoble and Lille. After that each resource from Grenoble runs the sleep 1 command. The duration of those commands is automatically logged. The duration of the command for each resource is printed on screen. The mean is also displayed.

## Appendix A. List of g5k_init parameters

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

	:site => \["lille"\]
	:resources => \["nodes=1"\]
	:environment => "lenny-x64-base"
	:walltime => 3600
	:types => \["allow_classic_ssh"\]
	:no_cleanup => false
	:deployment_max_attempts => 1 >
	:submission_timeout => 5*60
	:deployment_timeout => 15*60

## Appendix B. Expo commands and global variables

* **$all** represents the general set of all reserved nodes.It is an object of ResourceSet class which contains the references to all reserved nodes represented by Resource objects. To check all the methods of ResourceSet and Resource classes see **lib/resourceset.rb**

* **task (node, command)** - execute **command** on **node** and wait till the command finishes its execution

* **atask (node, command)** - asyncronous task. Execute **command** on **node** and do not wait till the command finishes its execution
* **barrier** - wait for all asynchronous tasks to finish
* **ptask (location, targets, command)** - parallel task. Run **command** from **location** on all the **targets** in parallel, and wait till the command finishes.
* **copy (file, node, path={})** - copy **file** to **node** to the specified **path**. If path is not specified - copy to the default folder.
* **parallel_section( &block )** - executes sequential sections which are called in the **block** in parallel.
* **sequential_section( &block )** -- should be called from parallel_section; code from the block is executed sequentially.

## Appendix C. Old expo interface documentation

How to define a reservation:

	oargridsub :res=> "toulouse:nodes=2", :start_date=> "2012-01-17 14:37:00"

<a name="contact"></a>


## Contact
cristian.ruiz@imag.fr

<a name="publications"></a>


## Related Publications

Brice Videau, Corinne Touati, and Olivier Richard. 
Toward an experiment engine for lightweight grids. In MetroGrid workshop : Metrology for Grid Networks. ACM publishing, Lyon, France, October 2007.
{file:docs/bib/Metro07.html bibtex}

Brice Videau and Olivier Richard. Expo : un moteur de conduite d'expériences pour plates-formes dédiées. In Conférence Française en Systèmes d'Exploitation (CFSE), Fribourg, Switzerland, February 2008. 
{file:docs/bib/CFSE6.html bibtex}



