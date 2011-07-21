class Printer
  attr_reader :stdout
  attr_reader :stderr
  attr_reader :stdin

  def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
    @stdout, @stderr, @stdin = stdout, stderr, stdin
  end

  def highline
    @highline ||= begin
      require 'highline'
      HighLine.new
    end
  end

  # Prints a message to stdout. Aliased as +info+ for compatibility with
  # the logger API.
  def msg(message)
    stdout.puts message
    stdout.flush
  end

  alias :info :msg

  # Print a warning message
  def warn(message)
    msg("#{color('WARNING:', :yellow, :bold)} #{message}")
  end

  # Print an error message
  def error(message)
    msg("#{color('ERROR:', :red, :bold)} #{message}")
  end

  # Print a message describing a fatal error.
  def fatal(message)
    msg("#{color('FATAL:', :red, :bold)} #{message}")
  end

  def color(string, *colors)
    if color?
      highline.color(string, *colors)
    else
      string
    end
  end

  # Should colored output be used? Only on TTY
  def color?
    true
  end

end