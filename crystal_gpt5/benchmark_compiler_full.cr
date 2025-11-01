require "./src/compiler/file_loader"
require "./src/compiler/semantic/analyzer"

include CrystalGPT5

puts "=== Full Crystal Compiler Benchmark ==="
puts ""

COMPILER_ENTRY = "/Users/sergey/Projects/Crystal/crystal/src/compiler/crystal.cr"

# Add Crystal stdlib to search paths
search_paths = [
  File.dirname(COMPILER_ENTRY),  # /Users/sergey/Projects/Crystal/crystal/src/compiler
  "/Users/sergey/Projects/Crystal/crystal/src",  # For stdlib
  "lib"  # For shards
]

puts "Entry file: #{COMPILER_ENTRY}"
puts "Search paths: #{search_paths.size}"
puts ""

puts "--- Phase 1: Loading all files with requires ---"
loader = Compiler::FileLoader.new(search_paths)

start = Time.monotonic
begin
  program = loader.load_with_requires(COMPILER_ENTRY)
  load_time = (Time.monotonic - start).total_milliseconds

  stats = loader.stats
  puts "Success!"
  puts "  Time: #{load_time.round(2)} ms"
  puts "  Files loaded: #{stats[:files_loaded]}"
  puts "  Total nodes: #{stats[:total_nodes]}"
  puts "  Dependencies: #{stats[:dependency_count]}"
  puts ""

  # Calculate memory usage (rough estimate)
  bytes_per_node = 200  # Conservative estimate
  total_memory_mb = (stats[:total_nodes] * bytes_per_node) / (1024.0 * 1024.0)
  puts "  Estimated memory: #{total_memory_mb.round(2)} MB"
  puts ""

  # Phase 2: Semantic Analysis
  puts "--- Phase 2: Semantic Analysis ---"

  analyzer_start = Time.monotonic
  analyzer = Compiler::Semantic::Analyzer.new(program)
  analyzer.collect_symbols
  result = analyzer.resolve_names
  semantic_time = (Time.monotonic - analyzer_start).total_milliseconds

  puts "Success!"
  puts "  Time: #{semantic_time.round(2)} ms"
  puts "  Identifiers resolved: #{result.identifier_symbols.size}"
  puts "  Diagnostics: #{result.diagnostics.size}"
  puts ""

  # Total pipeline
  puts "--- Total Pipeline ---"
  total_time = load_time + semantic_time
  puts "  Loading: #{load_time.round(2)} ms (#{(load_time / total_time * 100).round(1)}%)"
  puts "  Semantic: #{semantic_time.round(2)} ms (#{(semantic_time / total_time * 100).round(1)}%)"
  puts "  Total: #{total_time.round(2)} ms"

rescue ex
  puts "Error: #{ex.message}"
  if ex.backtrace?
    puts ex.backtrace.first(10).join("\n")
  end
end
