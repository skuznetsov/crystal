require "./src/compiler/**"

# Test 1: return with value
source1 = <<-CRYSTAL
def test : Int32
  return 42
end
CRYSTAL

lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source1)
parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program

puts "=== Test 1: return 42 ==="
def_node = program.arena[program.roots[0]]
puts "Def node: #{def_node.kind}"

if body = def_node.def_body
  puts "Body size: #{body.size}"
  return_node = program.arena[body[0]]
  puts "First statement: #{return_node.kind}"

  if return_node.kind == CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Return
    puts "✓ Return node created"
    if value_id = return_node.return_value
      value_node = program.arena[value_id]
      puts "  Return value: #{value_node.kind} = #{String.new(value_node.literal.not_nil!)}"
    else
      puts "  No return value"
    end
  end
end

# Test 2: return without value
source2 = <<-CRYSTAL
def test2 : Nil
  return
end
CRYSTAL

lexer2 = CrystalGPT5::Compiler::Frontend::Lexer.new(source2)
parser2 = CrystalGPT5::Compiler::Frontend::Parser.new(lexer2)
program2 = parser2.parse_program

puts "\n=== Test 2: return (no value) ==="
def_node2 = program2.arena[program2.roots[0]]
if body2 = def_node2.def_body
  return_node2 = program2.arena[body2[0]]
  puts "Statement: #{return_node2.kind}"

  if return_node2.kind == CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Return
    puts "✓ Return node created"
    if return_node2.return_value
      puts "  Has return value"
    else
      puts "✓ No return value (correct)"
    end
  end
end
