# Manual test for Phase 3.6: Block Debugging Support
#
# Compile with: crystal build -d spec/manual/debug_blocks.cr -o /tmp/debug_blocks
# Debug with: lldb /tmp/debug_blocks
#
# Expected behavior:
# - Breakpoints inside blocks should work
# - Block parameters should be visible
# - Block local variables should be accessible
# - Variables captured from outer scope should be visible
# - Nested blocks should show variables from all scopes

def test_simple_block
  multiplier = 2
  items = [1, 2, 3]

  puts "=== Simple Block Test ==="
  items.each do |item|
    result = item * multiplier
    # Set breakpoint here: b debug_blocks.cr:19
    # Expected variables:
    # - multiplier = 2 (captured)
    # - item = current iteration value
    # - result = item * 2
    puts "Item: #{item}, Result: #{result}"
  end
end

def test_nested_blocks
  outer_var = 10
  items = [1, 2, 3]

  puts "\n=== Nested Blocks Test ==="
  items.each do |item|
    multipliers = [2, 3]
    results = [] of Int32

    multipliers.each do |mult|
      result = item * mult * outer_var
      results << result
      # Set breakpoint here: b debug_blocks.cr:40
      # Expected variables:
      # - outer_var = 10 (captured from function)
      # - item = outer loop value
      # - mult = inner loop value
      # - result = item * mult * outer_var
      if item == 2 && mult == 3
        puts "  Nested: item=#{item}, mult=#{mult}, result=#{result}"
      end
    end

    puts "  Item #{item}: results = #{results}"
  end
end

def test_closure
  factor = 5

  puts "\n=== Closure Test ==="
  calculator = ->(x : Int32) {
    result = x * factor
    # Set breakpoint here: b debug_blocks.cr:60
    # Expected variables:
    # - x = argument passed to closure
    # - factor = 5 (captured)
    # - result = x * factor
    puts "  Closure: #{x} * #{factor} = #{result}"
    result
  }

  [7, 14].each do |value|
    final = calculator.call(value)
    puts "  Final: #{final}"
  end
end

def test_multiple_captures
  a = 1
  b = 2
  c = 3

  puts "\n=== Multiple Captures Test ==="
  [10, 20].each do |x|
    # Set breakpoint here: b debug_blocks.cr:82
    # Expected variables:
    # - a = 1, b = 2, c = 3 (all captured)
    # - x = current value
    result = x + a + b + c
    puts "  #{x} + #{a} + #{b} + #{c} = #{result}"
  end
end

# Run all tests
test_simple_block
test_nested_blocks
test_closure
test_multiple_captures

puts "\n✅ All tests completed"
puts "\nTo debug:"
puts "  1. Compile: crystal build -d spec/manual/debug_blocks.cr -o /tmp/debug_blocks"
puts "  2. Debug: lldb /tmp/debug_blocks"
puts "  3. Set breakpoints at lines indicated in comments"
puts "  4. Run: r"
puts "  5. Inspect: frame variable, p <variable_name>"
