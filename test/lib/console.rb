module Console
  extend self

  def load
    ENV['N'] ||= '4'
    Bundler.require "debugger_#{RUBY_ENGINE}"
    define_reload
    define_rake
    load_examples
    clean_backtraces
    puts <<-MESSAGE
Debug console. Type `rake` to run the test suite. `bin/rake` also works for
develompent environments that rely on binstubs.

The example operations located in `test/examples` are loaded for you. To try one
out:

    [1] pry(Orchestra)> Orchestra.execute Examples::FizzBuzz, :up_to => 16, :stdout => $stdout

See the README.md as well as the examples themselves for more information. You
will need to reload the examples after raking (or invoking reload!)
    MESSAGE
  end

  def load_examples
    Dir["test/examples/**/*.rb"].each do |example_rb| Kernel.load example_rb end
  end

  def define_reload
    Pry::Commands.block_command "reload!", "Reload gem code" do
      puts "Reloading..."
      Object.send :remove_const, :Examples if Object.const_defined? :Examples
      Object.send :remove_const, :Orchestra if Object.const_defined? :Orchestra
      Kernel.load "lib/orchestra.rb"
      Console.load_examples
      orchestra = Object.const_get :Orchestra
      _pry_.binding_stack.push orchestra.__binding__
      _pry_.binding_stack.shift
    end
  end

  def define_rake
    Pry::Commands.create_command %r{(?:bin/)?rake}, keep_retval: true do
      description "Run the test suite"

      def process
        run "reload!"

        status = TestRunner.run_in_subprocess

        build_passed = status.exitstatus == 0
        operator = args.shift
        run_system_command(build_passed, operator, args) if operator
        build_passed
      end

      def run_system_command build_passed, operator, system_args
        if operator == '&&'
          system *system_args if build_passed
        elsif operator == '||' && !build_passed
          system *system_args unless build_passed
        else
          raise ArgumentError, "Must supply either '&&' or '||' operators, followed by a shell command"
        end
      end
    end
  end

  def clean_backtraces
    if RUBY_ENGINE == "rbx"
      Exception.class_eval do
        def render_with_filtering *args
          io = args[1] || STDERR
          args[1] = BacktraceFiltering::Rubinius.new io
          render_without_filtering *args
        end
        alias_method :render_without_filtering, :render
        alias_method :render, :render_with_filtering
      end
    end
  end

  module BacktraceFiltering
    REGEX = %r{(?:lib/orchestra|test)}i

    class Rubinius
      def initialize io
        @io = io
      end

      def puts message = "\n"
        dont_filter_yet = true
        message.each_line do |line|
          if line.match %r{ at }
            next unless dont_filter_yet or line.match REGEX
            dont_filter_yet = false
          end
          @io.puts line
        end
      end
    end
  end
end
