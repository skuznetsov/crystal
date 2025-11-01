require "./src/compiler/frontend/lexer"
require "./src/compiler/frontend/parser"
require "./src/compiler/semantic/analyzer"
require "compiler/crystal/syntax"

include CrystalGPT5

PARSER_FILE = "/Users/sergey/Projects/Crystal/crystal/src/compiler/crystal/syntax/parser.cr"
content = File.read(PARSER_FILE)

puts "=== FULL PIPELINE COMPARISON (Parser + Semantic) ==="
puts "File: #{PARSER_FILE}"
puts "File size: #{content.size} bytes (#{content.lines.size} lines)"
puts ""

# ===== ORIGINAL CRYSTAL: PARSER ONLY =====
puts "--- Original Crystal Parser Only ---"

# Warmup
3.times do
  Crystal::Parser.parse(content)
end

# Benchmark
original_parser_times = [] of Float64
10.times do
  start = Time.monotonic
  Crystal::Parser.parse(content)
  elapsed = (Time.monotonic - start).total_milliseconds
  original_parser_times << elapsed
  print "."
  STDOUT.flush
end

puts ""
original_parser_avg = original_parser_times.sum / original_parser_times.size
puts "Average: #{original_parser_avg.round(2)} ms"
puts "Min: #{original_parser_times.min.round(2)} ms"
puts "Max: #{original_parser_times.max.round(2)} ms"
puts ""

# ===== OUR PARSER ONLY =====
puts "--- CrystalGPT5 Parser Only ---"

# Warmup
3.times do
  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  parser.parse_program
end

# Benchmark
our_parser_times = [] of Float64
10.times do
  start = Time.monotonic
  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  parser.parse_program
  elapsed = (Time.monotonic - start).total_milliseconds
  our_parser_times << elapsed
  print "."
  STDOUT.flush
end

puts ""
our_parser_avg = our_parser_times.sum / our_parser_times.size
puts "Average: #{our_parser_avg.round(2)} ms"
puts "Min: #{our_parser_times.min.round(2)} ms"
puts "Max: #{our_parser_times.max.round(2)} ms"
puts ""

# ===== OUR FULL PIPELINE (Parser + Semantic) =====
puts "--- CrystalGPT5 Parser + Semantic ---"

# Warmup
3.times do
  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  program = parser.parse_program
  analyzer = Compiler::Semantic::Analyzer.new(program)
  analyzer.collect_symbols
  analyzer.resolve_names
end

# Benchmark
our_full_times = [] of Float64
10.times do
  start = Time.monotonic
  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  program = parser.parse_program
  analyzer = Compiler::Semantic::Analyzer.new(program)
  analyzer.collect_symbols
  analyzer.resolve_names
  elapsed = (Time.monotonic - start).total_milliseconds
  our_full_times << elapsed
  print "."
  STDOUT.flush
end

puts ""
our_full_avg = our_full_times.sum / our_full_times.size
puts "Average: #{our_full_avg.round(2)} ms"
puts "Min: #{our_full_times.min.round(2)} ms"
puts "Max: #{our_full_times.max.round(2)} ms"
puts ""

# ===== COMPARISON =====
puts "=== PARSER COMPARISON ==="
parser_ratio = our_parser_avg / original_parser_avg
puts "Original: #{original_parser_avg.round(2)} ms"
puts "Ours:     #{our_parser_avg.round(2)} ms"
puts "Ratio:    #{parser_ratio.round(3)}x"
puts ""

puts "=== SEMANTIC OVERHEAD (Our Implementation) ==="
semantic_overhead = our_full_avg - our_parser_avg
semantic_pct = (semantic_overhead / our_parser_avg * 100).round(1)
puts "Parser:   #{our_parser_avg.round(2)} ms"
puts "Semantic: #{semantic_overhead.round(2)} ms (#{semantic_pct}% overhead)"
puts "Total:    #{our_full_avg.round(2)} ms"
puts ""

puts "=== QUALITY CHECK ==="
lexer = Compiler::Frontend::Lexer.new(content)
parser = Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program
analyzer = Compiler::Semantic::Analyzer.new(program)
analyzer.collect_symbols
result = analyzer.resolve_names
puts "Identifier symbols resolved: #{result.identifier_symbols.size}"
puts "Diagnostics: #{result.diagnostics.size}"
