require "./runtime"
require "./compiler"

module CrystalGPT5
  VERSION = "0.1.0"

  # Entry point: for now just print roadmap info.
  def self.run(args : Array(String))
    Runtime.bootstrap
    Compiler::CLI.new(args).run
  end
end

CrystalGPT5.run(ARGV)
