### This class is to keep data about the experiment
### This is going to be a singleton class :)
require 'singleton'

class Experiment
  include Singleton
  def initialize
    @id = 1
    @commands = []
  end
  
  def add_command(command)
    @commands.push(command)
  end

  
  
  def show_commands
    @commands.each{|cmd| puts cmd}
  end

end
