require "spec"

require "../src/main"
require "../src/compiler/frontend/lexer"

describe CrystalGPT5::Compiler::Frontend::Lexer do
  it "tokenizes identifiers and numbers" do
    source = "foo 123\nbar"
    lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
    kinds = [] of CrystalGPT5::Compiler::Frontend::Token::Kind
    lexer.each_token { |token| kinds << token.kind }

    kinds.should eq([
      CrystalGPT5::Compiler::Frontend::Token::Kind::Identifier,
      CrystalGPT5::Compiler::Frontend::Token::Kind::Whitespace,
      CrystalGPT5::Compiler::Frontend::Token::Kind::Number,
      CrystalGPT5::Compiler::Frontend::Token::Kind::Newline,
      CrystalGPT5::Compiler::Frontend::Token::Kind::Identifier,
      CrystalGPT5::Compiler::Frontend::Token::Kind::EOF,
    ])
  end
end
