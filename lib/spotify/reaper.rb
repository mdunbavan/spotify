require 'atomic'

module Spotify
  # The Reaper!
  #
  # Garbage collection may happen in a separate thread, and if we are
  # unfortunate enough the main thread will hold the API lock around Spotify,
  # which makes it impossible for the GC thread to obtain the lock to release
  # pointers.
  #
  # When garbage collection happens in a separate thread, it’s possible that
  # the main threads will not run until garbage collection is finished. If the
  # GC thread deadlocks, the entire application deadlocks.
  #
  # The idea is to locklessly pass pointers that need releasing to a queue. The
  # worker working the queue should be safe to acquire the API lock because
  # nobody is waiting for the working queue to ever finish.
  class Reaper
    # Freeze to prevent against modification.
    EMPTY = [].freeze

    # Time to sleep between each reaping.
    IDLE_TIME = 1

    class << self
      # @return [Reaper] The Reaper.
      attr_accessor :instance

      # @return [Boolean] true if Reaper should terminate at exit.
      attr_accessor :terminate_at_exit
    end

    def initialize
      @run = true
      @queue = Atomic.new(EMPTY)

      @reaper = Thread.new do
        begin
          while @run
            pointers = @queue.swap(EMPTY)
            pointers.each(&:free)
            sleep(IDLE_TIME)
          end
        ensure
          Thread.current[:exception] = exception = $!
          Spotify.log "Spotify::Reaper WAS KILLED: #{exception}!" if exception
        end
      end
    end

    # Mark a pointer for release. Thread-safe, uses no locks.
    #
    # @param [#free] pointer
    def mark(pointer)
      # Possible race-condition here. Don't really care.
      if alive?
        Spotify.log "Spotify::Reaper#mark(#{pointer.inspect})"

        @queue.update do |queue|
          # this needs to be able to run without side-effects as many
          # times as may be needed
          [pointer].unshift(*queue)
        end
        @reaper.wakeup
      else
        Spotify.log "Spotify::Reaper is dead. Cannot mark (#{pointer.inspect})."
      end
    end

    # Terminate the Reaper. Will wait until the Reaper exits.
    def terminate(wait_time = IDLE_TIME)
      if alive?
        Spotify.log "Spotify::Reaper terminating."
        @run = false
        @reaper.wakeup
        unless @reaper.join(wait_time)
          Spotify.log "Spotify::Reaper did not terminate within #{wait_time}."
        end
      end
    end

    # @return [Boolean] true if the Reaper is alive.
    def alive?
      @reaper.alive?
    end

    @instance = new
    @terminate_at_exit = true
  end
end

at_exit do
  if Spotify::Reaper.terminate_at_exit
    Spotify::Reaper.instance.terminate
  end
end
