require "./src/compiler/frontend/lexer"
require "./src/compiler/frontend/parser"
require "./src/compiler/frontend/ast"

source = <<-CRYSTAL
class Foo
  @x : Int32
end
CRYSTAL

lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program

puts "Parsed successfully!"
puts "Roots: #{program.roots.size}"

if program.roots.size > 0
  class_node = program.arena[program.roots[0]]
  puts "First node kind: #{class_node.kind}"

  if class_node.kind == CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class
    puts "Class name: #{String.new(class_node.class_name.not_nil!)}"

    if body = class_node.class_body
      puts "Class body size: #{body.size}"
      body.each_with_index do |expr_id, i|
        node = program.arena[expr_id]
        puts "  [#{i}] #{node.kind}"
        if node.kind == CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::InstanceVarDecl
          puts "    - ivar: #{String.new(node.literal.not_nil!)}"
          puts "    - type: #{String.new(node.ivar_decl_type.not_nil!)}"
        end
      end
    end
  end
end
