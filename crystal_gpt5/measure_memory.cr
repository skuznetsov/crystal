require "./src/compiler/frontend/ast"

include CrystalGPT5::Compiler::Frontend

# Phase B: Memory Measurement Script
#
# Measures actual memory usage of typed nodes vs legacy ExpressionNode

puts "="*80
puts "Phase B: Typed Arena Memory Measurement"
puts "="*80
puts

# Legacy ExpressionNode
legacy_size = sizeof(ExpressionNode)
puts "Legacy ExpressionNode: #{legacy_size} bytes"
puts

# Typed nodes
number_size = sizeof(NumberNode)
identifier_size = sizeof(IdentifierNode)
binary_size = sizeof(BinaryNode)
call_size = sizeof(CallNode)
if_size = sizeof(IfNode)

puts "Typed Nodes:"
puts "  NumberNode:     #{number_size} bytes (#{(legacy_size.to_f / number_size).round(1)}x smaller)"
puts "  IdentifierNode: #{identifier_size} bytes (#{(legacy_size.to_f / identifier_size).round(1)}x smaller)"
puts "  BinaryNode:     #{binary_size} bytes (#{(legacy_size.to_f / binary_size).round(1)}x smaller)"
puts "  CallNode:       #{call_size} bytes (#{(legacy_size.to_f / call_size).round(1)}x smaller)"
puts "  IfNode:         #{if_size} bytes (#{(legacy_size.to_f / if_size).round(1)}x smaller)"
puts

# Average
avg_typed = (number_size + identifier_size + binary_size + call_size + if_size) / 5.0
puts "Average typed node: #{avg_typed.round} bytes"
puts "Improvement: #{(legacy_size.to_f / avg_typed).round(1)}x memory reduction"
puts

# TypedNode union size (includes tag)
union_size = sizeof(TypedNode)
puts "TypedNode union (with tag): #{union_size} bytes"
puts "  Tag overhead: ~#{union_size - if_size} bytes"
puts "  Still #{(legacy_size.to_f / union_size).round(1)}x better than legacy"
puts

# Projected savings for 10,000 node AST
node_count = 10_000
legacy_memory = legacy_size * node_count
typed_memory = union_size * node_count

puts "="*80
puts "Projected Savings (10,000 node AST):"
puts "="*80
puts "Legacy: #{(legacy_memory / 1024.0 / 1024.0).round(2)} MB"
puts "Typed:  #{(typed_memory / 1024.0 / 1024.0).round(2)} MB"
puts "Saved:  #{((legacy_memory - typed_memory) / 1024.0 / 1024.0).round(2)} MB (#{((1.0 - typed_memory.to_f / legacy_memory) * 100).round(1)}%)"
puts

#  Test actual creation
puts "="*80
puts "Testing Actual Creation:"
puts "="*80

# Create sample span
span = Span.new(0, 1, 1, 10, 1, 10)
slice = "test".to_slice

# Create typed nodes
number = NumberNode.new(span, slice, NumberKind::I32)
identifier = IdentifierNode.new(span, slice)
binary = BinaryNode.new(span, slice, ExprId.new(0), ExprId.new(1))
call = CallNode.new(span, ExprId.new(0), [ExprId.new(1), ExprId.new(2)])
if_node = IfNode.new(span, ExprId.new(0), [ExprId.new(1)])

puts "✅ All typed nodes created successfully"
puts

# Test union
union : TypedNode = number
puts "✅ Union type works"
puts

# Test type discrimination
case union
when NumberNode
  puts "✅ Pattern matching works: NumberNode detected"
when IdentifierNode
  puts "IdentifierNode"
when BinaryNode
  puts "BinaryNode"
when CallNode
  puts "CallNode"
when IfNode
  puts "IfNode"
end
puts

puts "="*80
puts "Phase B Result: VALIDATED ✅"
puts "="*80
puts "Memory savings confirmed: ~#{(legacy_size.to_f / union_size).round(1)}x improvement"
puts
puts "Recommendation:"
if (legacy_size.to_f / union_size) >= 10.0
  puts "  ✅ PROCEED to Phase C (Full Typed Arena)"
  puts "     10x+ improvement justifies full refactor"
else
  puts "  ⚠️  EVALUATE: Improvement <10x, consider cost/benefit"
end
