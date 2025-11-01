require "./src/compiler/frontend/lexer"
require "./src/compiler/frontend/parser"
require "./src/compiler/semantic/analyzer"

include CrystalGPT5

PARSER_FILE = "/Users/sergey/Projects/Crystal/crystal/src/compiler/crystal/syntax/parser.cr"
content = File.read(PARSER_FILE)

puts "=== CrystalGPT5 FULL PIPELINE BENCHMARK ==="
puts "File: #{PARSER_FILE}"
puts "File size: #{content.size} bytes (#{content.lines.size} lines)"
puts ""

# ===== Parser Only =====
puts "--- Parser Only ---"

# Warmup
3.times do
  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  parser.parse_program
end

# Benchmark
parser_times = [] of Float64
10.times do
  start = Time.monotonic
  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  parser.parse_program
  elapsed = (Time.monotonic - start).total_milliseconds
  parser_times << elapsed
  print "."
  STDOUT.flush
end

puts ""
parser_avg = parser_times.sum / parser_times.size
puts "Average: #{parser_avg.round(2)} ms"
puts "Min: #{parser_times.min.round(2)} ms"
puts "Max: #{parser_times.max.round(2)} ms"
puts ""

# ===== Parser + Semantic =====
puts "--- Parser + Semantic Analysis ---"

# Warmup
3.times do
  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  program = parser.parse_program
  analyzer = Compiler::Semantic::Analyzer.new(program)
  analyzer.resolve_names
end

# Benchmark
full_times = [] of Float64
10.times do
  start = Time.monotonic

  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  program = parser.parse_program
  analyzer = Compiler::Semantic::Analyzer.new(program)
  result = analyzer.resolve_names

  elapsed = (Time.monotonic - start).total_milliseconds
  full_times << elapsed
  print "."
  STDOUT.flush
end

puts ""
full_avg = full_times.sum / full_times.size
puts "Average: #{full_avg.round(2)} ms"
puts "Min: #{full_times.min.round(2)} ms"
puts "Max: #{full_times.max.round(2)} ms"
puts ""

# ===== Breakdown =====
puts "--- Component Breakdown ---"
semantic_avg = full_avg - parser_avg
puts "Parser:   #{parser_avg.round(2)} ms"
puts "Semantic: #{semantic_avg.round(2)} ms (#{(semantic_avg / parser_avg).round(2)}x parser)"
puts "Total:    #{full_avg.round(2)} ms"
puts ""

# ===== Analysis Quality =====
puts "--- Semantic Analysis Quality ---"

lexer = Compiler::Frontend::Lexer.new(content)
parser = Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program
analyzer = Compiler::Semantic::Analyzer.new(program)
result = analyzer.resolve_names

puts "Identifier symbols resolved: #{result.identifier_symbols.size}"
puts "Diagnostics: #{result.diagnostics.size}"
