require "./src/compiler/**"

source = "arr.each do |x|\n  puts x\nend"

lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program

puts "Diagnostics: #{parser.diagnostics.size}"
parser.diagnostics.each { |d| puts "  #{d.message}" }

program.roots.each do |root_id|
  node = program.arena[root_id]
  puts "Root: #{node.kind}"
  if node.kind.member_access? && (block_id = node.call_block)
    block = program.arena[block_id]
    puts "  Block: #{block.kind}"
    puts "  Params: #{block.block_params.try(&.map(&.name).join(", "))}"
    puts "  Body stmts: #{block.block_body.try(&.size) || 0}"
  end
end
