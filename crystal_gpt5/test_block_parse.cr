require "./src/compiler/**"

source = <<-CRYSTAL
def three_times
  yield 1
  yield 2
  yield 3
end

three_times do |n|
  puts n
end

arr = [1, 2, 3]
arr.each { |x| puts x }
CRYSTAL

lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program

puts "=== Parsing Results ==="
puts "Roots: #{program.roots.size}"
puts "Diagnostics: #{parser.diagnostics.size}"

parser.diagnostics.each do |diag|
  puts "  Error: #{diag.message}"
end

program.roots.each_with_index do |root_id, idx|
  node = program.arena[root_id]
  puts "\nRoot #{idx}: #{node.kind}"

  if node.kind == CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def
    puts "  Method: #{node.literal_string}"
    if body = node.def_body
      body.each do |stmt_id|
        stmt = program.arena[stmt_id]
        puts "  - Body stmt: #{stmt.kind}"
        if stmt.kind == CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Yield
          puts "    Yield args: #{stmt.yield_args.try(&.size) || 0}"
        end
      end
    end
  elsif node.kind == CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess
    puts "  Member: #{node.member ? String.new(node.member.not_nil!) : "nil"}"
    if block_id = node.call_block
      block = program.arena[block_id]
      puts "  Block attached: #{block.kind}"
      if params = block.block_params
        puts "    Params: #{params.map(&.name).join(", ")}"
      end
    end
  end
end
