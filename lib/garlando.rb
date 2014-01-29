require 'garlando/version'
require 'optparse'
require 'timeout'

module Garlando
  class Server
    COMMANDS = %i[start restart stop status]
    OPTIONS  = {
      server: 'thin',
      host:   '0.0.0.0',
      port:   65501,
      pid:    'tmp/pids/asset_server.pid',
      env:    'development',
      pwd:    Dir.pwd,
    }

    def initialize(options={})
      @options = OPTIONS.merge options
    end

    def call(command)
      raise ArgumentError unless COMMANDS.include? command
      method(command).call
    end

    def start
      abort 'server is already running?' if File.exists? pid_path
      abort "File could not found (#{env_path})" unless File.exists?(env_path)

      Process.daemon nochdir = true

      File.write pid_path, Process.pid.to_s
      at_exit { File.unlink pid_path }

      ENV['RACK_ENV'] = @options[:env]
      require env_path

      app = Rack::URLMap.new Rails.application.config.assets[:prefix] => Rails.application.assets
      srv = Rack::Handler.pick @options[:server]
      srv.run app, Host: @options[:host], Port: @options[:port]
    end

    def stop(aborting = true)
      unless File.exists?(pid_path)
        return unless aborting
        abort 'server is not running'
      end

      pid = File.read(pid_path).to_i
      Timeout.timeout(10) do
        loop do
          break unless system "ps -p #{pid} > /dev/null"
          Process.kill :INT, pid
          sleep 0.5
        end
      end
    end

    def restart
      stop aborting = false
      start
    end

    def status
      if File.exists? pid_path
        puts "server is running (#{File.read pid_path})"
      else
        puts 'server is not running'
      end
    end

    private

    def pid_path
      File.join @options[:pwd], @options[:pid]
    end

    def env_path
      File.join @options[:pwd], 'config/environment.rb'
    end
  end

  class CLI
    def self.perform(args)
      new.perform(args)
    end

    def perform(args)
      commands, options = parse(args)
      command = (commands.first || :restart).to_sym

      begin
        Server.new(options).call command
      rescue ArgumentError
        abort 'unsupported command'
      end
    end

    def parse(args)
      options = Server::OPTIONS.dup

      opt = OptionParser.new
      opt.on('-s', '--server SERVER')   { |v| options[:server] = v }
      opt.on('-o', '--host HOST')       { |v| options[:host] = v }
      opt.on('-p', '--port PORT')       { |v| options[:port] = v }
      opt.on('-P', '--pid FILE')        { |v| options[:pid]  = v }
      opt.on('-E', '--env ENVIRONMENT') { |v| options[:env]  = v }

      [opt.parse(args), options]
    end
  end
end
