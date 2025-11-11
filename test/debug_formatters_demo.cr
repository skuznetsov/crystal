# Demo file for testing Crystal LLDB formatters in VSCode
#
# How to use:
# 1. Open this file in VSCode
# 2. Set breakpoint on line 17 (puts statement)
# 3. Press F5 or use "Crystal: Debug Current File"
# 4. When breakpoint hits, use Debug Console:
#
# Variables panel will show formatted values automatically:
#   - my_string: "Hello, Crystal!"
#   - my_array: [1, 2, 3, 4, 5]
#   - my_hash: entries with keys/values
#   - my_set: Set{10, 20, 30, 40, 50}
#
# In Debug Console, you can use custom commands:
#   > crystal_size my_array
#   > crystal_at my_array 2
#   > crystal_keys my_hash

my_string = "Hello, Crystal!"
my_array = [1, 2, 3, 4, 5]
my_hash = {"one" => 1, "two" => 2, "three" => 3}
my_set = Set{10, 20, 30, 40, 50}
my_range = 1..10
my_tuple = {42, "answer"}
my_named_tuple = {x: 10, y: 20}

puts "Breakpoint here - check Variables panel and Debug Console!"

# Try these commands in Debug Console:
# crystal_size my_array     -> my_array.size = 5
# crystal_size my_hash      -> my_hash.size = 3
# crystal_size my_set       -> my_set.size = 5
# crystal_size my_string    -> my_string.size = 15
# crystal_at my_array 0     -> my_array[0] = 1
# crystal_at my_array 4     -> my_array[4] = 5
# crystal_keys my_hash      -> Keys: "one", "two", "three"

puts "Done!"
