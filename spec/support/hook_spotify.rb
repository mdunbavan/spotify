#
# Hooks into FFI for extra introspection during testing.
#
require 'ffi'

module Spotify
  # so that Spotify cannot extend again
  extend FFI::Library
  extend self

  attr_reader :attached_methods

  # stores function information that we can assert on later
  def attach_function(name, func, arguments, returns, options)
    args  = [name, func, arguments, returns, options]
    hargs = [:name, :func, :args, :returns].zip args
    @attached_methods ||= {}
    @attached_methods[name.to_s] = hash = Hash[hargs]

    super
  end

  # used to find the actual type of a thing
  def resolve_type(type)
    type = find_type(type)
    type = type.type if type.respond_to?(:type)
    type
  end

  # @return [Array<FFI::Struct>] all structs in Spotify namespace
  def structs
    constants.select { |x| const_get(x).is_a?(Class) && const_get(x) < FFI::Struct }
  end

  # allows us to test for Mac/Linux independently
  FFI::Platform::OS.replace(ENV.fetch('RUBY_PLATFORM') do
    puts "[WARN] Tests running with default ruby platform, #{::FFI::Platform::OS}, please be"
    puts "[WARN] specific in which platform to target by setting ENV[RUBY_PLATFORM]"
    puts "(warnings coming from #{__FILE__}:#{__LINE__})"
    puts
    ::FFI::Platform::OS
  end)
end

# All is in place, load it up
require 'spotify'