require "./src/compiler/frontend/lexer"

source = "return 42"

lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
tokens = [] of CrystalGPT5::Compiler::Frontend::Token

lexer.each_token do |token|
  tokens << token
  puts "#{token.kind}: '#{token.lexeme}'"
end

# Verify
if tokens[0].kind == CrystalGPT5::Compiler::Frontend::Token::Kind::Return
  puts "✓ return keyword recognized"
else
  puts "✗ return not recognized: #{tokens[0].kind}"
end
