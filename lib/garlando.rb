require 'garlando/version'
require 'optparse'
require 'timeout'

module Garlando
  class Server
    COMMANDS = %i[start restart stop status]
    OPTIONS  = {
      env:    'development',
      host:   '0.0.0.0',
      log:    'log/garlando.log',
      pid:    'tmp/pids/garlando.pid',
      port:   65501,
      pwd:    Dir.pwd,
      server: 'thin',
    }

    def initialize(options={})
      @options = OPTIONS.merge options
    end

    def call(command)
      raise ArgumentError unless COMMANDS.include? command
      method(command).call
    end

    def start
      abort 'server is already running?' if running?
      abort "File could not found (#{env_path})" unless File.exists?(env_path)

      Process.daemon nochdir = true

      File.write pid_path, Process.pid.to_s
      at_exit { File.unlink pid_path }

      reopen

      ENV['RACK_ENV'] = @options[:env]
      require env_path

      server.run application, Host: @options[:host], Port: @options[:port]
    end

    def stop
      return abort 'server is not running' unless running?

      pid = File.read(pid_path).to_i
      Timeout.timeout(10) do
        begin
          while running?
            Process.kill :INT, pid
            sleep 0.5
          end
        rescue Errno::ESRCH
        end
      end
    end

    def restart
      stop if running?
      start
    end

    def status
      if running?
        puts "server is running (#{File.read pid_path})"
      else
        puts 'server is not running'
      end
    end

    private

    def running?
      File.exists? pid_path
    end

    def pid_path
      File.join @options[:pwd], @options[:pid]
    end

    def env_path
      File.join @options[:pwd], 'config/environment.rb'
    end

    def reopen
      file = File.open File.join(@options[:pwd], @options[:log]), 'w+'
      [STDOUT, STDERR].each { |e| e.reopen file }
    end

    def server
      Rack::Handler.get @options[:server]
    end

    def application
      Rack::URLMap.new rails.config.assets[:prefix] => rails.assets
    end

    def rails
      Rails.application
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