require "./src/compiler/frontend/lexer"
require "./src/compiler/frontend/parser"
require "compiler/crystal/syntax"

include CrystalGPT5

PARSER_FILE = "/Users/sergey/Projects/Crystal/crystal/src/compiler/crystal/syntax/parser.cr"
content = File.read(PARSER_FILE)

puts "=== DIRECT COMPARISON BENCHMARK ==="
puts "File: #{PARSER_FILE}"
puts "File size: #{content.size} bytes (#{content.lines.size} lines)"
puts ""

# ===== ORIGINAL CRYSTAL PARSER =====
puts "--- Original Crystal Parser ---"

# Warmup
3.times do
  Crystal::Parser.parse(content)
end

# Benchmark
original_times = [] of Float64
10.times do
  start = Time.monotonic
  Crystal::Parser.parse(content)
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

# ===== OUR PARSER (crystal_gpt5) =====
puts "--- CrystalGPT5 Parser (TIER 2.4) ---"

# Warmup
3.times do
  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  parser.parse_program
end

# Benchmark
our_times = [] of Float64
10.times do
  start = Time.monotonic
  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  parser.parse_program
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
puts "--- Direct Comparison ---"
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
