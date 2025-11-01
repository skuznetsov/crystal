require "./src/compiler/file_loader"

COMPILER_ENTRY = "/Users/sergey/Projects/Crystal/crystal/src/compiler/crystal.cr"

search_paths = [
  "/Users/sergey/Projects/Crystal/crystal/src",
  "/Users/sergey/Projects/Crystal/crystal/lib",
]

puts "=== File Loading Benchmark: Sequential vs Parallel ==="
puts ""
puts "Entry: #{COMPILER_ENTRY}"
puts "Search paths: #{search_paths.size}"
puts ""

# Benchmark: Sequential loading
puts "--- Sequential Loading ---"
loader_seq = CrystalGPT5::Compiler::FileLoader.new(search_paths, parallel: false)

start = Time.monotonic
program_seq = loader_seq.load_with_requires(COMPILER_ENTRY)
time_seq = (Time.monotonic - start).total_milliseconds

stats_seq = loader_seq.stats
puts "  Time: #{time_seq.round(2)} ms"
puts "  Files: #{stats_seq[:files_loaded]}"
puts "  Nodes: #{stats_seq[:total_nodes]}"
puts ""

# Benchmark: Parallel loading
puts "--- Parallel Loading ---"
loader_par = CrystalGPT5::Compiler::FileLoader.new(search_paths, parallel: true)

start = Time.monotonic
program_par = loader_par.load_with_requires(COMPILER_ENTRY)
time_par = (Time.monotonic - start).total_milliseconds

stats_par = loader_par.stats
puts "  Time: #{time_par.round(2)} ms"
puts "  Files: #{stats_par[:files_loaded]}"
puts "  Nodes: #{stats_par[:total_nodes]}"
puts ""

# Comparison
puts "--- Speedup ---"
speedup = time_seq / time_par
puts "  Sequential: #{time_seq.round(2)} ms"
puts "  Parallel:   #{time_par.round(2)} ms"
puts "  Speedup:    #{speedup.round(2)}x"
puts ""

# Verify same results
if stats_seq[:files_loaded] == stats_par[:files_loaded] &&
   stats_seq[:total_nodes] == stats_par[:total_nodes]
  puts "✓ Both loaders produced identical results"
else
  puts "✗ Warning: Different results!"
  puts "  Sequential: #{stats_seq[:files_loaded]} files, #{stats_seq[:total_nodes]} nodes"
  puts "  Parallel:   #{stats_par[:files_loaded]} files, #{stats_par[:total_nodes]} nodes"
end
