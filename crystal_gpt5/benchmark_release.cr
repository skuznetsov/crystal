#!/usr/bin/env crystal

# Direct benchmark using compiled binary (not crystal run!)
PARSER_FILE = "/Users/sergey/Projects/Crystal/crystal/src/compiler/crystal/syntax/parser.cr"

puts "=== RELEASE BUILD BENCHMARK ==="
puts "Running parser binary directly (not via crystal run)"
puts ""

# Use Time.measure for accurate timing
times = [] of Time::Span

10.times do |i|
  start = Time.monotonic
  result = `./bin/crystal_gpt5 #{PARSER_FILE} 2>&1`
  elapsed = Time.monotonic - start
  times << elapsed

  print "."
  STDOUT.flush
end

puts "\n"

avg_ms = times.sum.total_milliseconds / times.size
min_ms = times.min.total_milliseconds
max_ms = times.max.total_milliseconds

puts "Average: #{avg_ms.round(2)} ms"
puts "Min: #{min_ms.round(2)} ms"
puts "Max: #{max_ms.round(2)} ms"
