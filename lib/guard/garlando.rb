module Guard
  class Garlando < Plugin
    def initialize(options={})
      super
      tuples = %w(-s -o -p -P -E).zip(options.values_at *%i(server host port pid env))
      @option = tuples.reject { |_, e| e.nil? }.map { |e| e * ' ' } * ' '
    end

    def start
      system 'garlando #{@option}'
    end

    def stop
      system 'garlando stop'
    end
  end
end
