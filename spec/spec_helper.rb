# encoding: utf-8
require "rbgccxml"
require "rspec"
require "pry"
require "stringio"

require "spec/support/hook_spotify"
require "spec/support/spotify_util"
require "spec/support/spy_output"

# You can pregenerate new XML files through:
# gccxml spec/api-mac.h -fxml=spec/api-mac.xml
# gccxml spec/api-linux.h -fxml=spec/api-linux.xml
API_H_PATH = File.expand_path("../support/api-#{Spotify.platform}.h", __FILE__)
API_H_SRC  = File.read(API_H_PATH)
API_H_XML  = RbGCCXML.parse_xml(API_H_PATH.sub('.h', '.xml'))

RSpec.configure do |config|
  def api
    Spotify::API
  end

  config.filter_run_excluding(engine: ->(engine) do
    ! Array(engine).include?(RUBY_ENGINE)
  end)

  config.filter_run_excluding(ruby_version: ->(requirement) do
    ruby_version = Gem::Version.new(RUBY_VERSION)
    required_version = Gem::Requirement.new(requirement)
    ! required_version.satisfied_by?(ruby_version)
  end)

  config.around(:each) do |test|
    _, warnings = spy_output { test.run }
    if warnings =~ %r"lib/spotify"
      raise "#{example.description.inspect} caused a warning, #{warnings.inspect}"
    end
  end

  config.after(:each) do |test|
    Spotify::Reaper.instance.terminate
    Spotify::Reaper.instance = Spotify::Reaper.new(nil)
  end
end
