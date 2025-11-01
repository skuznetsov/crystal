require "benchmark"
require "./src/compiler/frontend/lexer"
require "./src/compiler/frontend/parser"

include CrystalGPT5

# Benchmark file to parse (original Crystal parser - a large file)
BENCHMARK_FILE = "/Users/sergey/Projects/Crystal/crystal/src/compiler/crystal/syntax/parser.cr"

# Read file content once
content = File.read(BENCHMARK_FILE)
puts "Benchmarking parser on: #{BENCHMARK_FILE}"
puts "File size: #{content.size} bytes (#{content.lines.size} lines)"
puts ""

# Warmup runs
puts "Warming up..."
3.times do
  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  parser.parse_program
end

# Benchmark parsing speed
puts "\n=== SPEED BENCHMARK ==="
puts "Running 10 iterations..."

times = [] of Float64
10.times do |i|
  start = Time.monotonic

  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  program = parser.parse_program

  elapsed = (Time.monotonic - start).total_milliseconds
  times << elapsed

  print "."
  STDOUT.flush
end

puts "\n"
avg_time = times.sum / times.size
min_time = times.min
max_time = times.max

puts "Average time: #{avg_time.round(2)} ms"
puts "Min time: #{min_time.round(2)} ms"
puts "Max time: #{max_time.round(2)} ms"
puts "Throughput: #{(content.size / (avg_time / 1000.0) / 1024 / 1024).round(2)} MB/s"

# Memory usage estimation
puts "\n=== MEMORY USAGE ==="
puts "Parsing and measuring arena size..."

lexer = Compiler::Frontend::Lexer.new(content)
parser = Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program

# Count nodes in arena
node_count = program.roots.size
arena = program.arena

puts "Top-level expressions: #{node_count}"
puts "Total nodes in arena: #{arena.size}"
puts "Arena memory (estimated): #{(arena.size * 200).humanize_bytes}"  # ~200 bytes per node estimate
puts ""

# Compare with original compiler (manual test)
puts "\n=== COMPARISON WITH ORIGINAL CRYSTAL PARSER ==="
puts "To benchmark the original Crystal parser, run:"
puts "  time crystal run --no-debug -Dpreview_mt --release benchmark_original.cr"
puts ""
puts "Where benchmark_original.cr contains:"
puts "  require \"compiler/crystal/syntax\""
puts "  content = File.read(\"#{BENCHMARK_FILE}\")"
puts "  10.times { Crystal::Parser.parse(content) }"
