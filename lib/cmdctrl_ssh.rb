require 'net/ssh'
require 'net/ssh/gateway' ### it is necessary to require it.

## Net::SSH.start is supose to return a session
## open_channel has to be used inside a block of Net::SSH.start otherwise It wont work.

## This approach is very promising I can get almost every data, that I get with CtrlCmd

class CmdCtrlSSH

  attr_reader :stdout ,:stdin, :stderr, :exit_status
  attr_reader :start_time, :end_time, :cmd

  def initialize(cmd=nil,host="",user="",gateway=nil,gw_user=nil)
    @cmd = cmd
    @host = host
    @user = user
    @gateway = gateway
    @gw_user = gw_user
  end

  def run(cmd)
    @stdout = []
    @stderr = []
    @cmd = cmd
    # @ssh.exec!(@cmd)
    @start_time = Time.now.to_f

    if @gateway == nil then
      Net::SSH.start(@host,@user) do |session|
        session.open_channel do |ch|
          ch.exec @cmd do |ch, success|
            raise "could not execute command" unless success
            ## probably here we can set up the return status
            # "on_data" is called when the process writes something to stdout
            ch.on_data do |c, data|
              @stdout << data
            end
            # "on_extended_data" is called when the process writes something to stderr
            ch.on_extended_data do |c, type, data|
              @stderr << data
            end

            ch.on_request "exit-status" do |ch, data|
              @exit_status = data.read_long
#              puts "process terminated with exit status: #{data.read_long}"
            end


            ch.on_close {
              @end_time = Time.now.to_f
            }

          end
        end
      end
    else

    ## now if there is a gateway defined
      gateway = Net::SSH::Gateway.new(@gateway,@gw_user)
      # puts "Using gateway"
      gateway.ssh(@host,@user) do |session|
        session.open_channel do |ch|
          ch.exec @cmd do |ch,success|
            raise "could not execute command" unless success

            ch.on_data do |c, data|
              @stdout << data
            end

            ch.on_extended_data do |c,type,data|
              @stderr << data
            end

            ch.on_request "exit-status" do |ch, data|
              @exit_status = data.read_long
            end

            ch.on_close {
              @end_time = Time.now.to_f
            }
          end
        end
      end
    end

  end

  def run_time
    return @end_time - @start_time
  end

end
