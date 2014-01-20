# -*- coding: utf-8 -*-
require 'tempfile'
require 'thread'

#module Expo

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
  # Creates a new Resource Object.
  # @param [type] type of the source
  # @param [properties] object property
  # @param [String] String name
  # @return [resource] Resource Object
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

  # Return the name of the resource.
  # @return [String] the name of the resource
  def name
    return @properties[:name]
  end

  #Sets the name of the resource.
  def name=(name)
    @properties[:name] = name
    return self
  end

  def ssh_user
    return @properties[:ssh_user]
  end
        
  def gw_ssh_user
    return @properties[:gw_ssh_user]
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

  def gateway=(host)
    @properties[:gateway] = host
    return self
  end
  
  alias gw gateway
  
  def job
    return @properties[:id] if @properties[:id]
    return 0
  end


  #Use to make the list of machines for
  #the taktuk command
  def make_taktuk_command()
    machine_base = "-m #{self.name} "
    if @properties[:multiplicity].nil? then
      if @properties[:cmd].nil? then
         return machine_base
       else
        return " #{machine_base} -[ exec [ #{properties[:cmd]} ] -]"
      end
    else
      if @properties[:cmd].nil? then
        return machine_list
      else
        if @properties[:cmd].is_a?(Array) then
          final_cmd=""
          @properties[:cmd].each{ |cmd|
            final_cmd+=" #{machine_base} -[ exec [ #{cmd} ] -]"
          }
        end
        return final_cmd
      end
    end

  end
end

class ResourceSet < Resource
  attr_accessor :resources
  def initialize( type = :resource_set, name = nil )
    super( type, nil, name )
    @resources = Array::new
    @resource_files = Hash::new
  end

  #Creates a copy of the ResourceSet Object
  ## I have to modify this, in order to take into account the type
  def copy
    result = ResourceSet::new(self.type)
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
  # if a gateway is defined we have to wrap the first element in a resourceset
  def first ( type=nil )
    if @properties[:outside] then
      return self[0..0]
    else
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
  end

  def first_h (type=nil)
    self[0..0]
  end    

  def select_resource( props )
    @resources.each { |resource|
      if resource.corresponds( props ) then
        return resource
      end 
    }
    return false## temporal modification, other whise it return the same resourceSet object
  end 

  ## This function select resource
  ## look through all the hierarchy of the resourceSet 
  ## Even though there are several nested resourceSets

  ## Now this function accepts optionally a block as a parameter
  def select_resource_h( props = nil, &block )
    if not block then
      @resources.each { |resource|
        if resource.is_a?(ResourceSet) then

          resource.corresponds( props ) ? (return resource) : result = resource.select_resource_h( props )
          
          return result if result
        ## we have to examine if it is a Resouce because,
        ## There could be several with the same id
        elsif resource.corresponds( props) then
          return resource
        end
      }
      return false
    else
      @resources.each{ |resource|
        if resource.is_a?(ResourceSet) then
          block.call( resource ) ? (return resource) : result = resource.select_resource_h( props, &block )
          return result if result
        elsif block.call( resource )
          return resource
        end
      }
    end
  end
    

#  def select( type=nil, props=nil , &block)
  def select(props = nil, &block)  
    set = ResourceSet::new
    if not block then
      set.properties.replace( @properties )
      set.type = self.type
      @resources.each { |resource|
        #if not type or resource.type == type then
        
          if resource.corresponds( props ) then
            set.resources.push( resource.copy )
            # end  
          # elsif type != :resource_set and resource.kind_of?(ResourceSet) then
          elsif resource.kind_of?(ResourceSet) then
            #result = resource.select( type, props )
            result = resource.select(props)
            set.resources.push( result ) if result
#          set.resources.push( resource.select( type, props ) )
          end
        
      }
      return false if set.resources.length == 0
    else
      set.properties.replace( @properties )
      @resources.each { |resource|
        # if not type or resource.type == type then
        if block.call( resource ) then
          set.resources.push( resource.copy )
        # end
        #elsif type != :resource_set and resource.kind_of?(ResourceSet) then
        elsif resource.kind_of?(ResourceSet) then
          result = resource.select(props, &block)
          set.resources.push( result) if result 
        end
      }
      return false if set.resources.length == 0
    end
    return set
  end


  def combination(length)
    set_per = []
    (0..self.length-1).each{ |a|
      (a..self.length-1).each{ |b|
        unless a==b
          set = ResourceSet::new
          set.properties.replace(@properties)
          set.resources.push(self[a])
          set.resources.push(self[b])
          set_per.push(set)
        end
      }
    }
    return set_per
  end


  def delete_first(resource)
    @resources.each_index { |i|
      if @resources[i] == resource then
        @resources.delete_at(i)
        return resource
      elsif @resources[i].kind_of?(ResourceSet) then
        if @resources[i].delete_first(resource) then
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


  def nodes_has_property?(property_name)
    self.each(:node){ |res|
      return false unless res.properties.has_key?(property_name)
    }
    return true
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
        @resources[i].delete_if( &block )
      end
    }
    return self
  end
  
  #Puts all the resource hierarchy into one ResourceSet.
  #the type defines the level
  def flatten(level=nil)
    set = ResourceSet::new
    self.each(level){ |resource|

      set.resources.push( resource.copy )
      # if not type or resource.type == type then
      #   set.resources.push( resource.copy )
      #   if resource.kind_of?(ResourceSet) then
      #     # set.resources.last.resources.clear
      #   end
      # end
      # if resource.kind_of?(ResourceSet) then
      #   set.resources.concat(resource.flatten(type).resources)
      # end
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
        
      elsif slice_step.kind_of?(Array) then
        number = slice_step.shift.to_i
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
  
  def each_slice_double( type = nil, &block )
    self.each_slice( type, lambda { |i| 2**i }, &block )
  end
  ## Fix Me  is the type really important , or were are going to deal always with nodes
  def each_slice_array( slices=1, &block)
    self.each_slice( nil,slices, &block)
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
	
  # Returns the number of resources in the ResourceSet
  # @return [Integer] the number of resources
  def length()
    count=0
    self.each(:node){ |resource|
      count+=1
    }
    return count
  end

  # Returns a subset of the ResourceSet.
  # @note It can be used with a range as a parameter.
  # @param [Range] index	Returns a subset specified by the range.
  # @param [String] index	Returns a subset which is belongs to the same cluster.
  # @param [Integer] index	Returns just one resource.
  # @return [ResourceSet] 	a ResourceSet object
  # @example 
  #	all[1..6] extract resources from 1 to 6
  #	all["lyon"] extract the resources form lyon cluster
  #  	all[0]  return just one resource.
  def []( index )
    count=0
    resource_set = self.copy
    it = ResourceSetIterator::new(self,:node)
    if index.kind_of?(Range) then
      self.each(:node){ |node|
        resource = it.resource
        if resource then
          if (count < index.first ) or (count > index.max) then
            resource_set.delete(resource)
          end
        end
        count+=1
        it.next
      }
      ## The resourceset withtout resources should be clean out
      object_print = ""
      until object_print == resource_set.to_yaml do
        object_print = resource_set.to_yaml
        resource_set.delete_if{ |res|
          if res.type != :node  then ## We erase all the resource set without resources
            res.length == 0 
          end
        }
      end
      return resource_set
    end
    # resource_set = ResourceSet::new
    # it = ResourceSetIterator::new(self,:node)
    # if index.kind_of?(Range) then
    #   self.each(:node){ |node|
    #     resource=it.resource
    #     if resource then
    #       if (count >= index.first ) and (count <= index.max) then
    #         resource_set.resources.push( resource )
    #       end
    #     end
    #     count+=1
    #     it.next
    #   }
    #   resource_set.properties=self.properties.clone
    #   return resource_set
    # end
    if index.kind_of?(String) then
      return select_resource_h(:name => index ) 
      # it = ResourceSetIterator::new(self,:resource_set)
      # self.each(:resource_set) { |resourceset|
      #   if resourceset.properties[:alias] == index then
      #     return resourceset
      #   end
      # }
    end
    #For this case a number is passed and we return a resource Object
    self.each(:node){ |resource|
      resource=it.resource
      if resource then
        if count==index then
          #resource_set.resources.push( resource )
          return resource
        end
      end
      count+=1
      it.next
    }
  end
  
  # Returns a resouce or an array of resources.
  # @return [Resource] a resource or array of resources
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
  
  # Returns a ResourceSet with unique elements.
  # @return [ResourceSet] 	with unique elements
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

  # Generates and return the path of the file which contains the list of the tipe of resource
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
  
  def gen_keys(type=nil )
    puts "Creating public keys for cluster ssh comunication"
    resource_set = self.uniq.flatten(type)
    resource_set.each { |resource|
      cmd = "scp "
      cmd += "-r ~/.ssh/ "
      ### here we have to deal with the user ## we have to define one way to put the user.
      cmd += " root@#{resource.properties[:name]}:~"
      command_result = $client.asynchronous_command(cmd)
      $client.command_wait(command_result["command_number"],1)
      result = $client.command_result(command_result["command_number"])
      puts cmd
      puts result["stdout"]
      puts result["stderr"]
    }
  end
  #Generates a directory.xml file for using as a resources 
  #For Gush.
  def make_gush_file( update = false)
    gush_file = File::new("directory.xml","w+")
    gush_file.puts("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
    gush_file.puts("<gush>")
    resource_set = self.flatten(:node)
    resource_set.each{ |resource|
      gush_file.puts( "<resource_manager type=\"ssh\">")
      gush_file.puts("<node hostname=\"#{resource.properties[:name]}:15400\" user=\"lig_expe\" group=\"local\" />" )
      
      gush_file.puts("</resource_manager>")
    }
    gush_file.puts("</gush>")
    gush_file.close
    return gush_file.path
  end

  #Creates the taktuk command to execute on the ResourceSet
  #It takes into account if the resources are grouped under
  #different gateways in order to perform this execution more
  #efficiently.
  # the parameter cmd was erase because of the taktuk wrapper
  ## When using the option gateway with TakTuk,
  # The command is not executed in that node
  def make_taktuk_command()
    str_cmd = ""
    #pd : séparation resource set/noeuds
    if self.gw != "localhost" then
      sets = false
      sets_cmd = ""
      @resources.each { |x|
        if x.instance_of?(ResourceSet) then
          sets = true
          sets_cmd += x.make_taktuk_command()
        end
      }
      str_cmd += " --gateway #{self.gw} -[ " + sets_cmd + " -]" if sets
      nodes = false
      nodes_cmd = ""
      @resources.each { |x|
        if x.type == :node then
          nodes = true
          nodes_cmd += x.make_taktuk_command()
        end
      }
      str_cmd += " -l #{self.gw_ssh_user} --gateway #{self.gw} -[ -l #{self.ssh_user} " + nodes_cmd + " -]" if nodes 
    else
      nodes = false
      nodes_cmd = ""
      first = ""
      @resources.each { |x|
       #if x.type == :node then
          # first = x.name if not nodes
          # nodes = true
          nodes_cmd += x.make_taktuk_command()
       # end
      }
      puts " results of the command #{nodes_cmd}"
      str_cmd += nodes_cmd  #if nodes
      sets = false
      sets_cmd = ""
      @resources.each { |x|
        if x.instance_of?(ResourceSet) then
          sets = true
          sets_cmd += x.make_taktuk_command()
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


#it working backwards level =1 should be the nodes

# Now the the iterators can be initialized with an integer
# which specifies the level of depth 
class ResourceSetIterator
  attr_accessor :current, :iterator, :resource_set, :type
  def initialize( resource_set, level=nil)
    @resource_set = resource_set
    @iterator = nil
    @level = level
    @current = 0
   
    @resource_set.resources.each_index { |i|
      if @level == @resource_set.resources[i].type or @level == 1 then

        @current = i
        return
  
      elsif @resource_set.resources[i].kind_of?(ResourceSet) then
        if @level.is_a?(Fixnum) then
          @iterator = ResourceSetIterator::new(@resource_set.resources[i], @level-1)
        else
          @iterator = ResourceSetIterator::new(@resource_set.resources[i], @level)
        end
        if @iterator.resource then
          @current = i
          return
        else
          @iterator = nil
        end
     elsif not @level then
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
    @current += 1 unless @iterator
    while not res and @current < @resource_set.resources.size do
      if @iterator then
        @iterator.next
        res = @iterator.resource
        if not res then
          @iterator = nil
          @current += 1
        end
      elsif @level == @resource_set.resources[@current].type or @level==1 then
        res = @resource_set.resources[@current]
       
      elsif @resource_set.resources[@current].kind_of?(ResourceSet) then
        if @level.is_a?(Fixnum) then
          @iterator = ResourceSetIterator::new(@resource_set.resources[@current], @level-1)
        else
          @iterator = ResourceSetIterator::new(@resource_set.resources[@current], @level)
        end
     
        # @iterator = ResourceSetIterator::new(@resource_set.resources[@current], @type)
        res = @iterator.resource
        if not res then
          @iterator = nil
          @current += 1
        end
      elsif not @level then
        res = @resource_set.resources[@current]
      else
        @current += 1
      end
    end
    return self
  end
end
