require 'tempfile'
require 'thread'

module Expo

class NameSet

        def initialize
                @names = Hash::new
                @mutex = Mutex::new
        end

        def get_name(name)
                string = nil
                @mutex.synchronize {
                        if @names[name] then
                                @names[name] += 1
                                string = name + @names[name].to_s
                        else
                                string = name
                                @names[name] = 1
                        end
                }
                return string
        end

end
#A Resource maps a computational resource to an object which keeps 
#Certains characteritics such as type, name, gateway.
class Resource
        attr_accessor :type, :properties
        #Creates a new Resource Object.
	def initialize( type, properties=nil, name=nil )
                @type = type
                @properties = Hash::new
                if properties then
                  #----replaces the contents of @properties hash with
                  #----contents of 'properties' hash
                  @properties.replace(properties)
                end
                if name then
                        @properties[:name] = name
                end
        end

	#return the name of the resource.
        def name
                return @properties[:name]
        end

	#Sets the name of the resource.
        def name=(name)
                @properties[:name] = name
                return self
        end

	#Returns the name of the resource.
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
      
	#Creates a copy of the resource object.
        def copy
                result = Resource::new(@type)
                result.properties.replace( @properties )
                return result
        end

	#Equality, Two Resource objects are equal if they have the 
	#same type and the same properties as well.
        def ==( res )
                @type == res.type and @properties == res.properties
        end

	#Returns true if self and other are the same object.
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

	#Returns the name of the gateway
	def gateway
		return @properties[:gateway] if @properties[:gateway]
		return "localhost"
	end

	alias gw gateway

	#Use to make the list of machines for
	#the taktuk command
        def make_taktuk_command(cmd)
                return " -m #{self.name}"
        end

end

class ResourceSetIterator
end

class ResourceSet < Resource
        attr_accessor :resources
        def initialize( name = nil )
                super( :resource_set, nil, name )
                @resources = Array::new
                @resource_files = Hash::new
        end

	#Creates a copy of the ResourceSet Object
        def copy
                result = ResourceSet::new
                result.properties.replace( @properties )
                @resources.each { |resource|
                        result.resources.push( resource.copy )
                }
                return result
        end

	#Add a Resource object to the ResourceSet
        def push( resource )
          @resources.push( resource )
          return self
        end

	# Return the first element which is an object of the Resource Class
        def first ( type=nil )
                @resources.each { |resource|
                        if resource.type == type then
                                return resource
                        elsif resource.kind_of?(ResourceSet) then
                                res = resource.first( type )
                                return res if res
                        elsif not type then
                          return resource
                        end
                }
            return nil
        end

        def select_resource( props )
          @resources.each { |resource|
            if resource.corresponds( props ) then
              return resource
            end 
          }   
        end 



        def select( type=nil, props=nil , &block)
                set = ResourceSet::new
                if not block then
                        set.properties.replace( @properties )
                        @resources.each { |resource|
                                if not type or resource.type == type then
                                        if resource.corresponds( props ) then
                                                set.resources.push( resource.copy )
                                        end
                                elsif type != :resource_set and resource.kind_of?(ResourceSet) then
                                        set.resources.push( resource.select( type, props ) )
                                end
                        }
                else
                        set.properties.replace( @properties )
                        @resources.each { |resource|
                                if not type or resource.type == type then
                                        if block.call( resource ) then
                                                set.resources.push( resource.copy )
                                        end
                                elsif type != :resource_set and resource.kind_of?(ResourceSet) then
                                        set.resources.push( resource.select( type, props , &block) )
                                end
                        }
                end
                return set
        end

        def delete_first(resource)
                @resources.each_index { |i|
                        if @resources[i] == resource then
                                @resources.delete_at(i)
                                return resource
                        elsif @resources[i].kind_of?(ResourceSet) then
                                if @resources[i].delete_first( resource ) then
                                        return resource
                                end
                        end
                }
                return nil
        end

        def delete_first_if(&block)
                @resources.each_index { |i|
                        if block.call(@resources[i]) then
                                return @resources.delete_at(i)
                        elsif @resources[i].kind_of?(ResourceSet) then
                                if (res = @resources[i].delete_first_if( &block )) then
                                        return res
                                end
                        end
                }
                return nil
        end

        def delete(resource)
                res = nil
                @resources.each_index { |i|
                        if @resources[i] == resource then
                                @resources.delete_at(i)
                                res = resource
                        elsif @resources[i].kind_of?(ResourceSet) then
                                #if @resources[i].delete_all( resource ) then
                                if @resources[i].delete( resource ) then
                                        res = resource
                                end
                        end
                }
                return res
        end

        def delete_if(&block)
                @resources.each_index { |i|
                        if block.call(@resources[i]) then
                                @resources.delete_at(i)
                        elsif @resources[i].kind_of?(ResourceSet) then
                                @resources[i].delete_all_if( &block )
                        end
                }
                return self
        end

	#Puts all the resource hierarchy into one ResourceSet.
	#The type can be either :node or :resource_set.
        def flatten( type = nil )
                set = ResourceSet::new
                @resources.each { |resource|
                        if not type or resource.type == type then
                                set.resources.push( resource.copy )
                                if resource.kind_of?(ResourceSet) then
                                        set.resources.last.resources.clear
                                end
                        end
                        if resource.kind_of?(ResourceSet) then
                                set.resources.concat( resource.flatten(type).resources )
                        end
                }
                return set
        end

        def flatten! (type = nil )
                set = self.flatten(type)
                @resources.replace(set.resources)
                return self
        end


        alias all flatten

	#Creates groups of increasing size based on
	#the slice_step paramater. This goes until the 
	#size of the ResourceSet.
        def each_slice( type = nil, slice_step = 1, &block)
                i = 1
                number = 0
                while true do
                        resource_set = ResourceSet::new
                        it = ResourceSetIterator::new(self, type)
                        #----is slice_step a block? if we call from
                        #----each_slice_power2 then yes
                        if slice_step.kind_of?(Proc) then
                                number = slice_step.call(i)
                        else
                                number += slice_step
                        end
                        return nil if number == 0
                        for j in 1..number do
                                resource = it.resource
                                if resource then
                                        resource_set.resources.push( resource )
                                else
                                        return nil
                                end
                                it.next
                        end
                        block.call( resource_set );
                        i += 1
                end 
        end

	#Invokes the block for each set of power of two resources.
        def each_slice_power2( type = nil, &block )
                self.each_slice( type, lambda { |i| i*i }, &block )
        end

	#Calls block once for each element in self, depending on the type of resource.
	#if the type is :resource_set, it is going to iterate over the several resoruce sets defined.
	#:node it is the default type which iterates over all the resources defined in the resource set.
        def each( type = nil, &block )
                it = ResourceSetIterator::new(self, type)
                while it.resource do
                        block.call( it.resource )
                        it.next
                end
        end
	
	#Returns the number of resources in the ResourceSet
	def length()
                count=0
                self.each(:node){ |resource|
                        count+=1
                }
                return count
        end

	#Extract part of a resourceSet.
	#It can be used with a range as a parameter.
	#For example $all[1..6] extract resources from 1 to 6
        def []( index )
              count=0
              resource_set = ResourceSet::new
              it = ResourceSetIterator::new(self,:node)
              if index.kind_of?(Range) then
                        self.each(:node){ |node|
                                resource=it.resource
                                if resource then
                                        if (count >= index.first ) and (count <= index.max) then
                                                resource_set.resources.push( resource )
                                        end
                                end
                                count+=1
                                it.next
                        }
                        return resource_set
              end
              self.each(:node){ |resource|
		   resource=it.resource
	           if resource then
                   	if count==index then
			   resource_set.resources.push( resource )
                           return resource_set
                   	end
		   end
                   count+=1
              }
        end

	# Return a resouce or an array of resources.	
	def to_resource
	    	if self.length == 1
			self.each(:node){ |resource|
				return resource
			}
		else
			resource_array=Array::new
			self.each(:node){ |resource|
				resource_array.push( resource )
				}
			return resource_array
		end
	end

        def ==( set )
                super and @resources == set.resources
        end

	#Equality between to resoruce sets.
        def eql?( set )
                super and @resources == set.resources
        end

	# Return a ResourceSet with unique elements.
        def uniq
                set = self.copy
                return set.uniq!
        end

        def uniq!
          i = 0
          while i < @resources.size-1 do
            pos = []
              for j in i+1...@resources.size
                                      if @resources[i].eql?(@resources[j]) then
                pos.push(j)
                                      end
                              end
            pos.reverse.each { |p|
                                      @resources.delete_at(p)
            }
            i = i + 1 
                      end
                      @resources.each { |x|
                              if x.instance_of?(ResourceSet) then
                                      x.uniq!
                              end
                      }
                      return self
        end

	#Generates and return the path of the file which contains the list of the tipe of resource
	#specify by the argument type.
        def resource_file( type=nil, update=false )
                if ( not @resource_files[type] ) or update then
                        @resource_files[type] = Tempfile::new("#{type}")
                        resource_set = self.flatten(type)
                        resource_set.each { |resource|
                                @resource_files[type].puts( resource.properties[:name] )
                        }
                        @resource_files[type].close
                        File.chmod(0644, @resource_files[type].path)
                end
                return @resource_files[type].path
        end

	#Generates and return the path of the file which contains the list  of the nodes' hostnames. Sometimes it is handy to have it.
	#eg. Use it with mpi.	 
        def node_file( update=false )
                resource_file( :node, update )
        end

	alias nodefile node_file

	#Creates the taktuk command to execute on the ResourceSet
	#It takes into account if the resources are grouped under
	#different gatways in order to perform this execution more
        #efficiently.
        def make_taktuk_command(cmd)
                str_cmd = ""
                #pd : séparation resource set/noeuds
                if self.gw != "localhost" then
                        sets = false
                        sets_cmd = ""
                        @resources.each { |x|
                                if x.instance_of?(ResourceSet) then
                                        sets = true
                                        sets_cmd += x.make_taktuk_command(cmd)
                                end
                        }
                        str_cmd += " -m #{self.gw} -[ " + sets_cmd + " -]" if sets
                        nodes = false
                        nodes_cmd = ""
                        @resources.each { |x|
                                if x.type == :node then
                                        nodes = true
                                        nodes_cmd += x.make_taktuk_command(cmd)
                                end
                        }
                        str_cmd += " -m #{self.gw} -[ " + nodes_cmd + " downcast exec [ #{cmd} ] -]" if nodes
                else
                        nodes = false
                        nodes_cmd = ""
                        first = ""
                        @resources.each { |x|
                                if x.type == :node then
                                        first = x.name if not nodes
                                        nodes = true
                                        nodes_cmd += x.make_taktuk_command(cmd)
                                end
                        }
                        str_cmd += " -m #{first} -[ " + nodes_cmd + " downcast exec [ #{cmd} ] -]" if nodes
                        sets = false
                        sets_cmd = ""
                        @resources.each { |x|
                                if x.instance_of?(ResourceSet) then
                                        sets = true
                                        sets_cmd += x.make_taktuk_command(cmd)
                                end
                        }
                        if sets then
                                if nodes then 
                                        str_cmd += " -m #{first} -[ " + sets_cmd + " -]"
                                else
                                        str_cmd += sets_cmd
                                end
                        end
                end
                return str_cmd
        end

end

class ResourceSetIterator
        attr_accessor :current, :iterator, :resource_set, :type
        def initialize( resource_set, type=nil)
                @resource_set = resource_set
                @iterator = nil
                @type = type
                @current = 0
                @resource_set.resources.each_index { |i|
                        if @type == @resource_set.resources[i].type then
                                @current = i
                                return
                        elsif @resource_set.resources[i].kind_of?(ResourceSet) then
                                @iterator = ResourceSetIterator::new(@resource_set.resources[i], @type)
                                if @iterator.resource then
                                        @current = i
                                        return
                                else
                                        @iterator = nil
                                end
                        elsif not @type then
                                @current = i
                                return
                        end
                }
                @current = @resource_set.resources.size
        end

        def resource
                return nil if( @current >= @resource_set.resources.size )
                if @iterator then
                        res = @iterator.resource
                else
                        res = @resource_set.resources[@current]
                end
                return res
        end

        def next
                res = nil
                @current += 1 if not @iterator
                while not res and @current < @resource_set.resources.size do
                        if @iterator then
                                @iterator.next
                                res = @iterator.resource
                                if not res then
                                        @iterator = nil
                                        @current += 1
                                end
                        elsif @type == @resource_set.resources[@current].type then
                                res = @resource_set.resources[@current]
                        elsif @resource_set.resources[@current].kind_of?(ResourceSet) then
                                @iterator = ResourceSetIterator::new(@resource_set.resources[@current], @type)
                                res = @iterator.resource
                                if not res then
                                        @iterator = nil
                                        @current += 1
                                end
                        elsif not @type then
                                res = @resource_set.resources[@current]
                        else
                                @current += 1
                        end
                end
                return self
        end
end

=begin
class ResourceSet

  def +(set)
    if set.gateway then
      if set.gateway != @gateway then
         raise "different gateways"
      end
    end
    result = ResourceSet::new(@resources+set.resources)
    result.gateway = @gateway
    return result
  end

=end

end
