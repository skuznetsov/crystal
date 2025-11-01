require "./src/compiler/frontend/lexer"
require "./src/compiler/frontend/parser"

include CrystalGPT5

PARSER_FILE = "/Users/sergey/Projects/Crystal/crystal/src/compiler/crystal/syntax/parser.cr"
content = File.read(PARSER_FILE)

puts "=== INLINE BENCHMARK (no process spawn) ==="
puts "File size: #{content.size} bytes"
puts ""

# Warmup
3.times do
  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  parser.parse_program
end

# Benchmark
times = [] of Float64
10.times do
  start = Time.monotonic
  lexer = Compiler::Frontend::Lexer.new(content)
  parser = Compiler::Frontend::Parser.new(lexer)
  parser.parse_program
  elapsed = (Time.monotonic - start).total_milliseconds
  times << elapsed
  print "."
  STDOUT.flush
end

puts "\n"
avg = times.sum / times.size
puts "Average: #{avg.round(2)} ms"
puts "Min: #{times.min.round(2)} ms"
puts "Max: #{times.max.round(2)} ms"
