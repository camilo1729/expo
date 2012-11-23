require 'resourceset'
require 'expolib'

module Expo

class GenericTask
        attr_accessor :type, :properties
        def initialize( type, properties=nil, name=nil )
                @type = type
                @properties = Hash::new
                if properties then
                        @properties.replace(properties)
                end
                if name then
                        @properties[:name] = name
                end
        end

        def name
                return @properties[:name]
        end

        def name=(name)
                @properties[:name] = name
                return self
        end

        def to_s
                return @properties[:name]
        end

        def corresponds( props )
                props.each_pair { |key,value|
                        if value.kind_of?(Proc) then
                                return false if not value.call(@properties[key])
                        else
                                return false if ( @properties[key] != value )
                        end
                }
                return true
        end

        def ==( res )
                @type == res.type and @properties == res.properties
        end

        def eql?( res )
                if self.class == res.class and @type == res.type then
			@properties.each_pair { |key,value|
				return false if res.properties[key] != value
			}
			return true
		else
			return false
		end
        end

end

class Task < GenericTask
        attr_accessor :command, :resources, :env_var
        def initialize( command = nil, resources = nil, name = nil )
                super( :task, nil, name)
                @command = command
                @resources = resources
                @env_var = nil
             
        end
        
	#Execute a command over the resource set defined at the
	#moment the Task object was created
        def execute
          path,exec,params = treat_task self.command
                cmd = "ruby taktuk2yaml.rb -s"
                cmd += $ssh_connector
          #cmd += " -l #{$ssh_user}" if !$ssh_user.nil?
		cmd += " -t #{$ssh_timeout}" if !$ssh_timeout.nil?
                # Allowing the definition of environmental variables
                if @env_var.nil? then
                  cmd += @resources.make_taktuk_command(" 'cd #{path} ; #{exec} #{params}' ")
                else
                  cmd += @resources.make_taktuk_command(" 'cd #{path} ; export #{@env_var} ; #{exec} #{params}' ")
                end


                command_result = $client.asynchronous_command(cmd)
                $client.command_wait(command_result["command_number"],1)
                final_result = make_taktuk_result(command_result["command_number"])
          log_task(exec,final_result,"(#{ self.name}): Parallel")
          return final_result
        end

	def make_taktuk_command
		return @resources.make_taktuk_command(self.command)
	end
end

#TaskSet defines a set of task which are executed in parallel over the
#resources specified in the individual tasks.
class TaskSet < GenericTask
        attr_accessor :tasks
        def initialize( name = nil )
                super( :task_set, nil, name )
                @tasks = Array::new
        end

	#Add task to the set.
        def push( task )
                @tasks.push( task )
		return self
        end

	#Execute the task in the set in parallel.
	#Just one taktuk command is created 
	#which contains each of the commands in the set
        def execute
                cmd = "ruby taktuk2yaml.rb -s"
                cmd += $ssh_connector
                @tasks.each { |t|
                        cmd += t.make_taktuk_command
                }
                command_result = $client.asynchronous_command(cmd)
                $client.command_wait(command_result["command_number"],1)
                return make_taktuk_result(command_result["command_number"])
        end

	def make_taktuk_command
		cmd = ""
		@tasks.each { |t|
		        cmd += t.make_taktuk_command
		}
		return cmd
	end
end

# Execute task  sequentially  over a set of resources
class TaskStream < GenericTask
        attr_accessor :tasks
        def initialize( name = nil )
                super( :task_stream, nil, name )
                @tasks = Array::new
        end

        def push( task )
                @tasks.push( task )
		return self
        end
	#Execute the task in sequential.
	#it uses one taktuk command for each command in the set
        def execute
		results = Array::new
                @tasks.each { |t|
                        results.push(t.execute)
                }
		return results
        end
end

end
