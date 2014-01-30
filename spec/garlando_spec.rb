require 'spec_helper'
require 'tempfile'

describe Garlando::CLI do
  let(:cli) { Garlando::CLI.new }

  describe '#parse' do
    it 'return command' do
      commands, _ = cli.parse %w[start]

      expect(commands).to eq ['start']
    end

    it 'return options' do
      _, options = cli.parse %w[-s puma]

      expect(options[:server]).to eq 'puma'
    end
  end

  describe '#perform' do
    before { Garlando::Server.any_instance.stub(:call) }

    it 'default command' do
      cli.perform %w[]

      allow_any_instance_of(Garlando::Server).to receive(:call).with(:restart)
    end

    it 'send command' do
      cli.perform %w[foo]

      allow_any_instance_of(Garlando::Server).to receive(:call).with(:foo)
    end
  end
end

describe Garlando::Server do
  let(:server) { Garlando::Server.new }

  describe '#call' do
    it 'raise ArgumentError' do
      expect { server.call :unsupported_command }.to raise_error ArgumentError
    end

    it 'otherwise' do
      server.stub start: nil
      server.call :start

      allow(server).to receive :start
    end
  end

  describe '#restart' do
    before { server.stub stop: nil, start: nil }

    it 'call stop' do
      server.restart

      allow(server).to receive(:stop)
    end

    it 'call start' do
      server.restart

      allow(server).to receive(:start)
    end
  end

  describe '#stop' do
    context 'When server is not running' do
      before { server.stub running?: false, abort: nil }

      it 'return immediate' do
        server.stop

        allow(server).to receive(:abort).with('server is not running')
      end
    end

    context 'When server is running' do
      let(:pid) { 1234567890 }

      before do
        @temp = Tempfile.new 'garlando'
        @temp.write pid
        @temp.flush

        server.stub pid_path: @temp.path

        Process.stub(:kill) { raise Errno::ESRCH }
      end

      after { @temp.close }

      it 'send SIGINT to server' do
        server.stop

        allow(Process).to receive(:kill).with(:INT, pid)
      end
    end
  end
end
