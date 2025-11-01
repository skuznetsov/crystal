require "./src/compiler/frontend/lexer"
require "./src/compiler/frontend/parser"
require "./src/compiler/semantic/analyzer"
require "compiler/crystal/syntax"
require "compiler/crystal/program"

include CrystalGPT5

PARSER_FILE = "/Users/sergey/Projects/Crystal/crystal/src/compiler/crystal/syntax/parser.cr"
content = File.read(PARSER_FILE)

puts "=== FULL PIPELINE BENCHMARK (Parser + Semantic) ==="
puts "File: #{PARSER_FILE}"
puts "File size: #{content.size} bytes (#{content.lines.size} lines)"
puts ""

# ===== ORIGINAL CRYSTAL (Parser + Semantic) =====
puts "--- Original Crystal (Parser + Semantic) ---"

# Warmup
3.times do
  program = Crystal::Program.new
  node = Crystal::Parser.parse(content)
  program.semantic(node)
end

# Benchmark
original_times = [] of Float64
10.times do
  start = Time.monotonic

  program = Crystal::Program.new
  node = Crystal::Parser.parse(content)
  program.semantic(node)

  elapsed = (Time.monotonic - start).total_milliseconds
  original_times << elapsed
  print "."
  STDOUT.flush
end

puts ""
original_avg = original_times.sum / original_times.size
puts "Average: #{original_avg.round(2)} ms"
puts "Min: #{original_times.min.round(2)} ms"
puts "Max: #{original_times.max.round(2)} ms"
puts ""

# ===== OUR PARSER (Parser + Semantic) =====
puts "--- CrystalGPT5 (Parser + Semantic) ---"

# Warmup
3.times do
  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  program = parser.parse_program
  analyzer = Compiler::Semantic::Analyzer.new(program)
  analyzer.resolve_names
end

# Benchmark
our_times = [] of Float64
10.times do
  start = Time.monotonic

  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  program = parser.parse_program
  analyzer = Compiler::Semantic::Analyzer.new(program)
  analyzer.resolve_names

  elapsed = (Time.monotonic - start).total_milliseconds
  our_times << elapsed
  print "."
  STDOUT.flush
end

puts ""
our_avg = our_times.sum / our_times.size
puts "Average: #{our_avg.round(2)} ms"
puts "Min: #{our_times.min.round(2)} ms"
puts "Max: #{our_times.max.round(2)} ms"
puts ""

# ===== COMPARISON =====
puts "--- Full Pipeline Comparison ---"
ratio = our_avg / original_avg
puts "Original: #{original_avg.round(2)} ms"
puts "Ours:     #{our_avg.round(2)} ms"
puts "Ratio:    #{ratio.round(3)}x (#{ratio > 1 ? "slower" : "faster"})"
if ratio > 1
  slowdown_pct = ((ratio - 1) * 100).round(1)
  puts "          #{slowdown_pct}% slower"
else
  speedup_pct = ((1 - ratio) * 100).round(1)
  puts "          #{speedup_pct}% faster"
end
puts ""

# Min time comparison
min_ratio = our_times.min / original_times.min
puts "Best times:"
puts "Original: #{original_times.min.round(2)} ms"
puts "Ours:     #{our_times.min.round(2)} ms"
puts "Ratio:    #{min_ratio.round(3)}x"
puts ""

# ===== BREAKDOWN: Parser vs Semantic =====
puts "--- Component Breakdown ---"

# Our parser only
puts "Our parser only:"
parser_times = [] of Float64
5.times do
  start = Time.monotonic
  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  parser.parse_program
  elapsed = (Time.monotonic - start).total_milliseconds
  parser_times << elapsed
end
our_parser_avg = parser_times.sum / parser_times.size
puts "  Average: #{our_parser_avg.round(2)} ms"

# Our semantic only (reuse parsed program)
puts "Our semantic only (amortized):"
semantic_avg = our_avg - our_parser_avg
puts "  Average: ~#{semantic_avg.round(2)} ms"
puts "  Ratio: #{(semantic_avg / our_parser_avg).round(2)}x parser time"
