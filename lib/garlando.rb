require 'garlando/version'
require 'optparse'
require 'timeout'
require 'net/http'

module Garlando
  class Server
    COMMANDS = %i(start restart stop status)
    OPTIONS  = {
      env:    'development',
      host:   '0.0.0.0',
      log:    'log/garlando.log',
      pid:    'tmp/pids/garlando.pid',
      port:   65501,
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
      abort 'server is already running?' if running?
      abort "File could not found (#{env_path})" unless File.exist?(env_path)

      Process.daemon nochdir = true

      File.write pid_path, Process.pid.to_s
      at_exit { File.unlink pid_path }

      prepare

      server.run application, Host: @options[:host], Port: @options[:port]
    end

    def stop
      return abort 'server is not running' unless running?

      pid = File.read(pid_path).to_i
      Timeout.timeout(10) do
        begin
          kill pid while running?
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

    def kill(pid, sig=:INT)
      Process.kill sig, pid
      sleep 0.5
    end

    def running?
      File.exists? pid_path
    end

    def pid_path
      File.join @options[:pwd], @options[:pid]
    end

    def env_path
      File.join @options[:pwd], 'config/environment.rb'
    end

    def log_path
      File.join @options[:pwd], @options[:log]
    end

    def reopen
      file = File.open log_path, 'a'
      [STDOUT, STDERR].each { |e| e.reopen file }
    end

    def server
      Rack::Handler.default
    end

    def application
      Rack::Logger.new(Rack::CommonLogger.new(Rack::URLMap.new(rails.config.assets[:prefix] => rails.assets)))
    end

    def rails
      Rails.application
    end

    def logger
      Logger.new log_path
    end

    def relogging
      rails.assets.logger = logger
    end

    def spinup
      check = lambda do |path|
        begin
          Net::HTTP.start(@options[:host], @options[:port]) do |http|
            http.open_timeout = http.read_timeout = nil
            http.get path
            throw :finish
          end
        rescue Errno::ECONNREFUSED
        end
      end
      [
        "#{rails.config.assets[:prefix]}/application.js",
        "#{rails.config.assets[:prefix]}/application.css",
      ].each do |_path|
        Thread.new(_path) do |path|
          catch(:finish) { loop { check.call path } }
        end
      end
    end

    def prepare
      reopen

      ENV['RACK_ENV'] = @options[:env]
      require env_path

      relogging

      spinup
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
      opt.on('-o', '--host HOST')       { |v| options[:host] = v }
      opt.on('-p', '--port PORT')       { |v| options[:port] = v }
      opt.on('-P', '--pid FILE')        { |v| options[:pid]  = v }
      opt.on('-E', '--env ENVIRONMENT') { |v| options[:env]  = v }

      [opt.parse(args), options]
    end
  end
end
