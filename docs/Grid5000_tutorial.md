Grid5000 Tutorial Expo and Kameleon
===================================

This demonstration aims to present Kameleon and Expo, two tools that respectively ease the process of environment construction and experiment deployment and execution. 
This demonstration targets two common activities in an infrastructure as Grid'5000. 
The creation and customization of an environment so that it meets the user requirements and 
its conrresponding deployment and experiment managment.
The demonstration will focus in three primary aspects:

- The construction of a Grid'5000 deployable image using kameleon. 
Which allows the users to create software appliances, virtual machines and CD images by specifying a recipe with the software stack wanted ( OS + libraries + Data ). 
The aformentioned task is acomplished easily, with a simple setup and configuration and in the user's local machine, without the need to perform any deployment.
- Experiment interaction and managment with Expo. It provides an interactive console, which allows the user to set up its experiment by using a Ruby syntax. 
Expo provides abstractions that ease the resources and task management during the description of an experiment.
- Finally the creation of an experiment description file and its respective execution as a stand alone experiment.


In this tutorial you are going to be walked through the experimentation process,
Given that in different testbeds it is possible to deploy is 
The objective of this first part is to create a deployable Grid5000 image
with PAPI and TAU packages install. Everything in the user machine.
We are going to follow the following steps:

- **Install kameleon**
- **Create a debian Base image**
- **Use this initial image to add PAPI and TAU packages**

Simple Example of the recipe file:


	global:
		distrib: debian-lenny
		workdir_base: /var/tmp/kameleon/
		distrib_repository: http://ftp.us.debian.org/debian/
		arch: i386
		kernel_arch: "686"
	steps:
		- check_deps
		- bootstrap
		- debian/system_config
		- software_install
		- kernel_install
		- strip
		- build_appliance:
			- create_raw_image
			- copy_system_tree
			- install_grub
			- save_as_raw
			- save_as_qcow2
        - clean

Every recipe is mainly divided in two sections:

- **global**: Definition of all the variables to use.
- **steps**: Definition of all the macro steps to execute in order to build the image.

Steps are classified as macrosteps and microsteps. Therefore microsteps can be seen as the commands executed
and macrosteps are just an abstraction which groups different microsteps that has one particular objective.

## Installing kameleon

Prerequisites to the kameleon installation: 
Make sure *ruby*, *debootstrap*, *rsync*, *parted*, *kpartx*, *losetup*, *dmsetup*, *grub-install*, *awk*, *sed* 
are installed on your computer, you may also need *qemu-img* and *VBoxManage* to generate qemu or VirtualBox images.
The only non-standard ruby module that's needed is *session*. 
Installation tarball can be found in the redist directory. 
Upon extracting, session module can be installed by invoking `ruby install.rb` script.

**Note**: also available as a gem: `gem install session` and then run as `sudo ruby -rubygems ./kameleon.rb`

## Creating the Debian base System

We have to start by creating the following recipe to build a basic debian system.

	#### Basic Debian Kameleon recipe ###
	global:
		workdir_base: /home/cristian/tmp/kameleon
    
    # Debian specific
		distrib: debian
		debian_version_name: squeeze
		distrib_repository: http://ftp.fr.debian.org/debian/
		output_environment_file_system_type: ext4
    
		include_dir: scripts
    # Architecture
		arch: amd64
		kernel_arch: "amd64"
    #
    # Network configuration
		network_hostname: kameleon
    # 
    
	steps:
	# Checking availability of tool used during the process
		- debian_check_deps
		- check_deps:
		  - rsync
		  - building_appliance
		  - building_kvm_images
    # Creation of the debian base system using debootstap 
		- bootstrap
	# Some system coniguration
		- system_config:
		  - fstab
		- root_passwd
		- mount_proc
	# Grid5000 network management
		- g5k/g5k-update-host-name
		- kernel_install
		- strip
		- umount_proc
	#Building the appliance
		- build_appliance:
		  - clean_udev
		  - create_raw_image
		  - create_nbd_device
		  - mkfs
		  - mount_image
		  - copy_system_tree
		  - install_grub
		  - umount_image
		  - save_as_raw 
	# Creating Grid5000 deployable image
		- save_as_g5k
		- clean

To run kameleon, run as root (because we need to create a chroot)

	./kameleon -i ~/Repositories/kameleon/ debian_base.yaml

This process will generate in the work directory defined in the variable *workdir_base* a directory with a date as a name example:

	/home/cristian/tmp/kameleon/2012-11-22-08-43-56/

If we go to this directory, we will see the following structure:

	~/tmp/kameleon/2012-11-22-08-43-56$ ls
	debian.g5k.dsc  debian.g5k.tgz  debian.raw  image.raw  kameleon_env

Therefore:

- **debian.g5k.dsc**: description file used by kadeploy.
- **debian.g5k.tgz**: tarball with the file system.
- **debian.raw**: it is the raw file system copied from disc.
- **kameleon_env**: It is the log of all the commands executed.

So we can use the *debian.g5k.tgz* and *debian.g5k.dsc* and transfer them to any site in Grid5000 and deploy a base debian system.

But instead of that let's add more software to this image.

If the software we want to add, is available in the debian repository we just create in the section *global:* a variable 
call *extra_packages*, it would look something like this:

	extra_packages: "vim less bzip2 openssh-server rsync gnupg locales debian-keyring console-tools mingetty gcc g++ make patch build-essential"

And after that we need to add a step:

	- software_install:
		- extra_packages
		
The step *software install*  execute the debian application manager to install the packages defined in the variable *extra_packages*

If the software is not available in the debian respositories or you have to compile form source because you need special configuration, 
you have to create a step which is kind of bash kameleon complain script.
It includes the definition of Micro and Macro steps. So, we are going to do it for installing PAPI in the base image. 
This is how it looks like:

    ## Macro steps for installing PAPI 
    ### http://icl.cs.utk.edu/projects/papi/downloads/papi-4.4.0.tar.gz
	papi:
		- get_unpack:
		  - exec_chroot: bash -c "cd /root/ ; wget $$papi_repository/papi-$$papi_version.tar.gz"
		  - exec_chroot: bash -c "cd /root/ ; tar -xzf papi-$$papi_version.tar.gz -C ."
		  - exec_chroot: bash -c "cd /root/ ; rm papi-$$papi_version.tar.gz"
			
		- papi_install:
		  - exec_chroot: bash -c "cd /root/papi-$$papi_version/src/ ; ./configure"
		  - exec_chroot: bash -c "cd /root/papi-$$papi_version/src/; make; make install"

Here we keep it simple, we just execute commands but it can do more things such as writing into files.

We now are going to crate the step for TAU.

    ## Macro steps for installing TAU profiling tool
	tau:
		- get_unpack:
		  - exec_chroot: bash -c "cd /root/ ; wget $$pdt_repository/pdt.tgz"
		  - exec_chroot: bash -c "cd /root/ ; wget $$tau_repository/tau.tgz"
		  - exec_chroot: bash -c "cd /root/ ; tar -xzf pdt.tgz -C ."
		  - exec_chroot: bash -c "cd /root/ ; tar -xzf tau.tgz -C ."
		  - exec_chroot: bash -c "cd /root/ ; rm pdt.tgz"
		  - exec_chroot: bash -c "cd /root/ ; rm tau.tgz"
		  
		- pdt_install:
		  - exec_chroot: bash -c "cd /root/pdtoolkit-$$pdt_version ; ./configure "
		  - exec_chroot: bash -c "cd /root/pdtoolkit-$$pdt_version; make clean install"
		  
		- tau_install_with_mpi:
		  - exec_chroot: bash -c "cd /root/tau-$$tau_version ; ./configure -pdt=/root/pdtoolkit-$$pdt_version -mpiinc=/usr/include/ -mpilib=/usr/lib/"
		  - exec_chroot: bash -c "cd /root/tau-$$tau_version; make clean install"
		  
		- tau_install_with_papi:
		  - exec_chroot: bash -c "cd /root/tau-$$tau_version ; ./configure -pdt=/root/pdtoolkit-$$pdt_version -papi=/root/papi-4.4.0/ "
		  - exec_chroot: bash -c "cd /root/tau-$$tau_version; make clean install"

And Finally we create a recipe with both steps. 

This is how it look like the *global* section for this final recipe.

	 global:
		 workdir_base: /home/cristian/tmp/kameleon
         # Debian specific
         distrib: debian
         debian_version_name: squeeze
         distrib_repository: http://ftp.fr.debian.org/debian/
         output_environment_file_system_type: ext4
         #
         include_dir: scripts
         # Architecture
         arch: amd64
         kernel_arch: "amd64"
         #
         extra_packages: "vim less bzip2 openssh-server rsync gnupg locales debian-keyring console-tools mingetty gcc g++ make patch build-essential"
         # Network configuration
         network_hostname: kameleon
         # 
         checkpoint_file: /home/cristian/kameleon/grid5000_school/img/debian_base.tgz
         #
         #PDT variable definition
	     pdt_repository: http://tau.uoregon.edu/
         pdt_version: 3.18.1 
         # TAU variable definition
         tau_repository: http://tau.uoregon.edu/
         tau_version: 2.22-p1
         #PAPI variable definition
		 papi_repository: http://icl.cs.utk.edu/projects/papi/downloads/
		 papi_version: 4.4.0 

And the *steps* section will look like this:

	steps:
	   - checkpoint_resume
	   - software_install:
		   - extra_packages
	   - PAPI/papi
	   - TAU/tau:
		 - get_unpack
		 - pdt_install
		 - tau_install_with_papi  
	   - umount_proc
	   
	   - build_appliance:
		   - clean_udev
		   - create_raw_image
		   - create_nbd_device
		   - mkfs
		   - mount_image
		   - copy_system_tree
		   - install_grub
		   - umount_image
		   - save_as_raw 
	   - save_as_g5k
	   - clean

Now that the image is build let's deployed with Expo.


## Using Expo

We have to install it first, please go to {http://expo.gforge.inria.fr/file.Grid5000_tutorial.html Expo Getting Started}
After that you have to copy the image with the description file to one site of Grid5000 and do the setup in order to make the
image available form a url inside Grid5000 to see how to do this 
{https://www.grid5000.fr/mediawiki/index.php/Deploy_environment-OAR2#Multi-site_experiments Kadeploy tutorial}


Execute the Expo Console:
	
    $ ./expo
	ruby 1.8.7 (2010-08-16 patchlevel 302) [x86_64-linux]
    Welcome to Expo Interactive Mode
    All the libraries have been loaded
    Opening Experiment
    Preparing resource container $all
    Connecting to the Grid5000 API
    Expo Console > 

And then create a reservation object:
	
	Expo Console > reserv=ExpoEngine::new(@connection)

Assign the environment url to the reservation:

	Expo Console > reserv.environment="http://public.grenoble.grid5000.fr/~cruizsanabria/environments/debian_papi_tau_g5k.dsc"

And the others parameters:

	Expo Console > reserv.site=["grenoble"]
	=> ["grenoble"]
	Expo Console > reserv.walltime=7200
	=> 7200

You can put the site of your preference that support performance counters, then run the reservation:

	2012-11-22 13:41:46 +0100 [DEBUG] In /home/cruizsanabria/Repositories/git/expo/bin 
	2012-11-22 13:41:46 +0100 [INFO] [ Expo Engine Grid5000 API ] Asking for Resources 
	2012-11-22 13:41:46 +0100 [INFO] [ Expo Engine Grid5000 API ] Number of nodes to reserve in site: grenoble => nodes=1 
	2012-11-22 13:41:46 +0100 [INFO] [grenoble] Launching job [no-submit=false]... 
	2012-11-22 13:41:58 +0100 [INFO] [grenoble] Got the following job: 1393107 
	2012-11-22 13:41:58 +0100 [INFO] [grenoble] Waiting for state=running for job #1393107 (expected start time="unknown")... 
	2012-11-22 13:42:08 +0100 [INFO] [grenoble] Job is running: 
	2012-11-22 13:42:08 +0100 [INFO] [ Expo Engine Grid5000 API ] Time Spent waiting for resources 22.08627 secs 
	2012-11-22 13:42:08 +0100 [INFO] [grenoble] Launching deployment [no-deploy=false]... 
	2012-11-22 13:42:08 +0100 [INFO] [grenoble] Got the following deployment: b84cba18ee0dac422ec5f527c027966bf0ebc686 
	2012-11-22 13:42:08 +0100 [INFO] [grenoble] Waiting for termination of deployment #b84cba18ee0dac422ec5f527c027966bf0ebc686 in grenoble... 
	2012-11-22 13:50:42 +0100 [INFO] [grenoble] Deployment is terminated: 
	2012-11-22 13:50:42 +0100 [INFO] [ Expo Engine Grid5000 API ] Time Spent deploying 513.91942 
	=> {:no_cancel=>false,
	:environment=>
	"http://public.grenoble.grid5000.fr/~cruizsanabria/environments/debian_papi_tau_g5k.dsc",
	:user=>"cruizsanabria",
	:deployment_timeout=>900,
	:public_key=>"/home/cruizsanabria/.ssh/id_rsa.pub",
	:site=>"grenoble",
	:parallel_reserve=>
    #<Grid5000::Campaign::Parallel:0x7fd86cdf5240

After the deployment, we can start using expo to interact with the machine, if we take a look at the variable `$all`,
we'll see something like this:

	Expo Console > $all
	=> #<Expo::ResourceSet:0x7fd86f908d60
	@properties={},
	@resource_files={},
	@resources=
	[#<Expo::ResourceSet:0x7fd86d01a048
		@properties=
		{:site=>"grenoble",
		:alias=>"edel",
		:gateway=>"frontend.grenoble.grid5000.fr",
		:name=>"ExpoEngine",
		:id=>1393107},
		@resource_files={},
		@resources=
			[#<Expo::Resource:0x7fd86d019df0
			@properties=
				{:site=>"grenoble",
				:gateway=>"frontend.grenoble.grid5000.fr",
				:name=>"edel-25.grenoble.grid5000.fr"},
			@type=:node>],
			@type=:resource_set>],
	@type=:resource_set>

Just a simple command to test:

	Expo Console > task $all.first.name, "hostname"
	edel-25.grenoble.grid5000.fr
	2012-11-22 14:03:31 +0100 [INFO] [ Sequential Task:3 ]  [ Executed ]   hostname  
	2012-11-22 14:03:31 +0100 [INFO] [ Sequential Task:3 ]  [ On Node ]  edel-25.grenoble.grid5000.fr  
	2012-11-22 14:03:31 +0100 [INFO] [ Sequential Task:3 ]  [ Elapsed Time ] 0.00247 secs 
	=> [3,
	[{"stdout"=>"edel-25.grenoble.grid5000.fr\n",
		"end_time"=>Thu Nov 22 14:03:30 +0100 2012,
		"host_name"=>"edel-25.grenoble.grid5000.fr",
		"stderr"=>"",
		"rank"=>"1",
		"status"=>"0",
		"command_line"=>"cd . ; hostname ",
		"start_time"=>Thu Nov 22 14:03:30 +0100 2012}]]

Just to get used to the syntax we can get and treat the output of commands

	Expo Console > id,res=task $all.first, "ls"
	papi-4.4.0
	pdtoolkit-3.18.1
	postinst.log
	tau-2.22-p1
	2012-11-22 14:05:22 +0100 [INFO] [ Sequential Task:5 ]  [ Executed ]   ls  
	2012-11-22 14:05:22 +0100 [INFO] [ Sequential Task:5 ]  [ On Node ]  edel-25.grenoble.grid5000.fr  
	2012-11-22 14:05:22 +0100 [INFO] [ Sequential Task:5 ]  [ Elapsed Time ] 0.00313 secs 
	=> [5,
	[{"stdout"=>"papi-4.4.0\npdtoolkit-3.18.1\npostinst.log\ntau-2.22-p1\n",
	"end_time"=>Thu Nov 22 14:05:22 +0100 2012,
	"host_name"=>"edel-25.grenoble.grid5000.fr",
	"stderr"=>"",
	"rank"=>"1",
	"status"=>"0",
	"command_line"=>"cd . ; ls ",
	"start_time"=>Thu Nov 22 14:05:22 +0100 2012}]
	
So we saved the output in the res variable, and then check its contents doing:

	Expo Console > res[0]["stdout"]
	=> "papi-4.4.0"
	=> "pdtoolkit-3.18.1"
	=> "postinst.log"
	=> "tau-2.22-p1"

Expo hooks in pry make the visualization of outputs easier recognizing that the string is the result of stdout 
and helping the readability.

Now let's execute something serious. Let's compile one of the examples of TAU

	Expo Console > id,res=task $all.first, "make -C tau-2.22-p1/examples/papi/"	
	2012-11-22 14:14:13 +0100 [INFO] [ Sequential Task:6 ]  [ Executed ]   make  
	2012-11-22 14:14:13 +0100 [INFO] [ Sequential Task:6 ]  [ On Node ]  edel-25.grenoble.grid5000.fr  
	2012-11-22 14:14:13 +0100 [INFO] [ Sequential Task:6 ]  [ Elapsed Time ] 0.29028 secs 
	=> [6,
	[{"stdout"=>
    "make: Entering directory `/root/tau-2.22-p1/examples/papi'\ng++   -I/root/tau-2.22-p1/include -DPROFILING_ON    simple.o -o simple  -L/root/tau-2.22-p1/x86_64/lib -lpapi",
	"end_time"=>Thu Nov 22 14:14:11 +0100 2012,
	"host_name"=>"edel-25.grenoble.grid5000.fr",
	"stderr"=>"",
	"rank"=>"1",
	"status"=>"0",
	"command_line"=>"cd . ; make -C tau-2.22-p1/examples/papi/",
	"start_time"=>Thu Nov 22 14:14:11 +0100 2012}]]
	
Expo offers another abstraction called **Task**, which is implemented as a Ruby **Class**.
This Class makes more clear the command execution through the experiment description.

To create a **Task** Object do the following:
	
	task_1=Task::new("/root/tau-2.22-p1/examples/papi/simple",$all,"Test 1")
	
Here we just created a task that is going to excute the example we have just created.
This task is going to be executed on the `$all` which for the moment is composed
of just one node.
This example shows the effect of using a strip mining optimization with the 
matrix multiply algorithm. Although both the regular multiply 
algorithm and the strip mining algorithm have the same number of floating
point operations, they have dramatically different cache behaviors. 
Using PAPI we can see the exact number of floating point operations and
secondary data cache misses as we will see.

To specify the counter in papi we want to use, we have to specify if by defining an environmental variable.
We should do something like this in a shell.

	export TAU_METRICS=TIME:PAPI_L2_DCM

For measuring the Level 2 data cache misses. Also because the default behavior generates all the profiling output
in directory located in the same directory were the application is located, we can change this by setting this
with the environmental variable `PROFILEDIR`.

	export PROFILEDIR=/root/
	
in order to do that with expo we can specify the environment definition:

	Expo Console > task_1.env_var="TAU_METRICS=TIME:PAPI_L2_DCM PROFILEDIR=/root/"

then we can proceed with the execution:

	Expo Console > task_1.execute
	012-11-23 14:06:37 +0100 [INFO] [ (Test 1): Parallel Task:21 ]  [ Executed ]   ./simple  
	2012-11-23 14:06:37 +0100 [INFO] [ (Test 1): Parallel Task:21 ]  [ On Node ]  chinqchint-43.lille.grid5000.fr  
	2012-11-23 14:06:37 +0100 [INFO] [ (Test 1): Parallel Task:21 ]  [ Elapsed Time ] 0.24925 secs 
	=> [21,
	[{"stdout"=>"",
	"end_time"=>Fri Nov 23 14:06:35 +0100 2012,
	"host_name"=>"chinqchint-43.lille.grid5000.fr",
	"stderr"=>"",
	"rank"=>"2",
	"status"=>"0",
	"command_line"=>
	"cd /root/tau-2.22-p1/examples/papi ; export TAU_METRICS=TIME:PAPI_L2_DCM PROFILEDIR=/root/ ; ./simple ",
	"start_time"=>Fri Nov 23 14:06:35 +0100 2012}]]

This will produce two diretory call `MULTI__TIME` and `MULTI__PAPI_L2_CDM` respectively.
These two directories contain values of the performance counters.
To see the content of this directory we need a tool call pprof.
So we create a task to execute this command and given that we dont have it , in the `PATH`, 
we should specified with Expo.

	Expo Console > analysis=Task::new("pprof -f MULTI__TIME/profile.0.0.0",$all,"Analysis")
	Expo Console > analysis.env_var="PATH=/root/tau-2.22-p1/x86_64/bin/"
	
And after run it:

	Expo Console > id,res=analy.execute
	
	Reading Profile files in MULTI__PAPI_L2_DCM/profile.0.0.0.*

    MULTI__PAPI_L2_DCM/profile.0.0.0
	---------------------------------------------------------------------------------------
	%Time   Exclusive   Inclusive       #Call      #Subrs Count/Call Name
		counts total counts                            
	---------------------------------------------------------------------------------------
	100.0           6          57           1           1         57 main() int (int, char **)
	89.5          21          51           1           2         51 multiply void (void)
	36.8          21          21           1           0         21 multiply-regular void (void)
	15.8           9           9           1           0          9 multiply-with-strip-mining-optimization void (void)
	
	2012-11-23 14:06:27 +0100 [INFO] [ (Analysis): Parallel Task:20 ]  [ Executed ]   pprof  
	2012-11-23 14:06:27 +0100 [INFO] [ (Analysis): Parallel Task:20 ]  [ On Node ]  chinqchint-43.lille.grid5000.fr  
	2012-11-23 14:06:27 +0100 [INFO] [ (Analysis): Parallel Task:20 ]  [ Elapsed Time ] 0.00471 secs 
	=> [20,
	[{"stdout"=>
    "Reading Profile files in MULTI__PAPI_L2_DCM/profile.0.0.0.*--\n%Time   Exclusive   Inclusive       #Call      #Subrs Count/Call Name
		\n           counts total counts                            
		---------------------------------------------------------------------------------------
		100.0           6          57           1           1         57 main() int (int, char **)
		89.5          21          51           1           2         51 multiply void (void)
		36.8          21          21           1           0         21 multiply-regular void (void)
		15.8           9           9           1           0          9 multiply-with-strip-mining-optimization void (void)",
	"end_time"=>Fri Nov 23 14:06:26 +0100 2012,
	"host_name"=>"chinqchint-43.lille.grid5000.fr",
	"stderr"=>"",
	"rank"=>"2",
	"status"=>"0",
	"command_line"=>
	"cd . ; export PATH=/root/tau-2.22-p1/x86_64/bin/ ; pprof -f MULTI__PAPI_L2_DCM/profile.0.0.0",
	"start_time"=>Fri Nov 23 14:06:26 +0100 2012}]]


To know how much time it took we execute:

	Expo Console > res.duration
	=> 0.00471





	
	


