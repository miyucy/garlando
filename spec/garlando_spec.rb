require 'spec_helper'

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
    it 'default command' do
      Garlando::Server.any_instance.stub(:call)
      # Garlando::Server.stub(new: true)
      cli.perform %w[]

      allow_any_instance_of(Garlando::Server).to receive(:call).with(:restart)
    end

    it 'send command' do
      Garlando::Server.any_instance.stub(:call)
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
end
