require "./src/compiler/frontend/lexer"
require "./src/compiler/frontend/parser"

source = <<-CR
class Greeter
  def greet(name)
    name
  end
end
CR

lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program

puts "Roots: #{program.roots.size}"
program.roots.each_with_index do |root_id, i|
  node = program.arena[root_id]
  puts "Root #{i}: kind=#{node.kind}"

  if node.kind.class?
    puts "  Class name: #{String.new(node.class_name.not_nil!)}"
    if body = node.class_body
      puts "  Class body size: #{body.size}"
      body.each_with_index do |expr_id, j|
        expr = program.arena[expr_id]
        puts "    Body[#{j}]: kind=#{expr.kind}"
        if expr.kind.def?
          puts "      Def name: #{String.new(expr.def_name.not_nil!)}"
        end
      end
    end
  end
end
