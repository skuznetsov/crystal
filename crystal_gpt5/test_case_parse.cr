require "./src/compiler/**"

source = <<-CRYSTAL
x = 2
result = case x
when 1
  "one"
when 2, 3
  "two or three"
else
  "other"
end
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

  if node.kind == CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign
    value_id = node.assign_value
    if value_id
      value_node = program.arena[value_id]
      puts "  Value: #{value_node.kind}"

      if value_node.kind == CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Case
        puts "  Case value present: #{value_node.case_value ? "yes" : "no"}"
        if branches = value_node.when_branches
          puts "  When branches: #{branches.size}"
          branches.each_with_index do |branch, i|
            puts "    Branch #{i}: #{branch.conditions.size} conditions, #{branch.body.size} statements"
          end
        end
        puts "  Else clause: #{value_node.case_else ? "yes" : "no"}"
      end
    end
  end
end
