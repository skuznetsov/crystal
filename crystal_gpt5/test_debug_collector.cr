require "./src/compiler/**"

source = <<-CRYSTAL
class Foo
  @x : Int32
end
CRYSTAL

lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program

puts "=== Parsed AST ==="
puts "Roots: #{program.roots.size}"
class_node = program.arena[program.roots[0]]
puts "Class node: #{class_node.kind}"

if body = class_node.class_body
  puts "Class body size: #{body.size}"
  body.each_with_index do |expr_id, i|
    node = program.arena[expr_id]
    puts "  [#{i}] #{node.kind}"
    if node.kind == CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::InstanceVarDecl
      puts "    - literal: #{node.literal.try { |s| String.new(s) }}"
      puts "    - ivar_decl_type: #{node.ivar_decl_type.try { |s| String.new(s) }}"
    end
  end
end

puts "\n=== Running SymbolCollector ==="
symbol_table = CrystalGPT5::Compiler::Semantic::SymbolTable.new(nil)
context = CrystalGPT5::Compiler::Semantic::Context.new(symbol_table)
collector = CrystalGPT5::Compiler::Semantic::SymbolCollector.new(program, context)
collector.collect

puts "\n=== Checking Symbol Table ==="
foo_symbol = context.symbol_table.lookup("Foo")
if foo_symbol.is_a?(CrystalGPT5::Compiler::Semantic::ClassSymbol)
  puts "Found Foo class symbol"
  puts "Instance vars: #{foo_symbol.instance_vars.inspect}"
  x_type = foo_symbol.get_instance_var_type("x")
  puts "@x type: #{x_type.inspect}"
else
  puts "Foo symbol is not a ClassSymbol: #{foo_symbol.inspect}"
end
