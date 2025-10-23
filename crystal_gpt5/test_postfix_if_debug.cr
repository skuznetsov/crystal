require "./src/compiler/**"

source = <<-CRYSTAL
def test : Int32
  x = 0
  while x < 10
    x = x + 1
    return x if x == 5
  end
  x
end
CRYSTAL

lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program

def_node = program.arena[program.roots[0]]
puts "Def body size: #{def_node.def_body.not_nil!.size}"

body = def_node.def_body.not_nil!
puts "\n=== Method body ==="
body.each_with_index do |expr_id, i|
  node = program.arena[expr_id]
  puts "[#{i}] #{node.kind}"
end

while_expr_id = body[1]
while_node = program.arena[while_expr_id]
puts "\n=== While body ==="
while_body = while_node.while_body.not_nil!
puts "While body size: #{while_body.size}"

while_body.each_with_index do |expr_id, i|
  node = program.arena[expr_id]
  puts "[#{i}] #{node.kind}"

  if node.kind == CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::If
    puts "  - if_condition: #{program.arena[node.if_condition.not_nil!].kind}"
    puts "  - if_then size: #{node.if_then.try(&.size) || "nil"}"
    if then_branch = node.if_then
      then_branch.each_with_index do |then_id, j|
        then_node = program.arena[then_id]
        puts "    [#{j}] #{then_node.kind}"
      end
    end
  end
end
