require 'spec_helper'
require 'tempfile'

describe Garlando::CLI do
  let(:cli) { Garlando::CLI.new }

  describe '#parse' do
    it 'return command' do
      commands, _ = cli.parse %w(start)

      expect(commands).to eq ['start']
    end

    it 'return options' do
      _, options = cli.parse %w(-o 192.168.0.1)

      expect(options[:host]).to eq '192.168.0.1'
    end
  end

  describe '#perform' do
    before { allow_any_instance_of(Garlando::Server).to receive(:call) }

    it 'default command' do
      expect_any_instance_of(Garlando::Server).to receive(:call).with(:restart)

      cli.perform []
    end

    it 'send command' do
      expect_any_instance_of(Garlando::Server).to receive(:call).with(:foo)

      cli.perform %w(foo)
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
      allow(server).to receive :start
      expect(server).to receive :start

      server.call :start
    end
  end

  describe '#restart' do
    before do
      allow(server).to receive(:stop)
      allow(server).to receive(:start)
      allow(server).to receive(:running?) { true }
    end

    it 'call stop' do
      expect(server).to receive(:stop)

      server.restart
    end

    it 'call start' do
      expect(server).to receive(:start)

      server.restart
    end
  end

  describe '#stop' do
    context 'When server is not running' do
      before do
        allow(server).to receive(:running?) { false }
        allow(server).to receive(:abort)
      end

      it 'return immediate' do
        expect(server).to receive(:abort).with('server is not running')

        server.stop
      end
    end

    context 'When server is running' do
      let(:pid) { 1234567890 }

      before do
        @temp = Tempfile.new 'garlando'
        @temp.write pid
        @temp.flush

        allow(server).to receive(:pid_path) { @temp.path }
        allow(Process).to receive(:kill) { raise Errno::ESRCH }
      end

      after { @temp.close }

      it 'send SIGINT to server' do
        expect(Process).to receive(:kill).with(:INT, pid)

        server.stop
      end
    end
  end
end
