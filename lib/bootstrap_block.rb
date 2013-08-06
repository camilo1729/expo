require 'rubygems'
require 'serializable_proc'

block = nil
file_block = ARGV[0]
#puts file_block
File.open(file_block){|f| block = Marshal.load(f)}
block.call
