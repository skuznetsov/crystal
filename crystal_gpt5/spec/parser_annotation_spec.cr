require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 92: annotation keyword (user-defined annotation declarations)" do
    it "parses simple annotation definition" do
      source = <<-CRYSTAL
      annotation MyAnnotation
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      annotation_node = arena[program.roots[0]]
      annotation_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Annotation)

      # Check name
      name = annotation_node.annotation_name
      name.should_not be_nil
      String.new(name.not_nil!).should eq("MyAnnotation")
    end

    it "parses annotation inside class" do
      source = <<-CRYSTAL
      class Foo
        annotation Internal
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      class_node = arena[program.roots[0]]
      class_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)

      class_body = class_node.class_body.not_nil!
      class_body.size.should eq(1)

      annotation_node = arena[class_body[0]]
      annotation_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Annotation)
      String.new(annotation_node.annotation_name.not_nil!).should eq("Internal")
    end

    it "parses annotation inside module" do
      source = <<-CRYSTAL
      module MyModule
        annotation Helper
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      module_node = arena[program.roots[0]]
      module_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Module)

      module_body = module_node.module_body.not_nil!
      module_body.size.should eq(1)

      annotation_node = arena[module_body[0]]
      annotation_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Annotation)
      String.new(annotation_node.annotation_name.not_nil!).should eq("Helper")
    end

    it "parses multiple annotations" do
      source = <<-CRYSTAL
      annotation First
      end

      annotation Second
      end

      annotation Third
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # First annotation
      ann1 = arena[program.roots[0]]
      ann1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Annotation)
      String.new(ann1.annotation_name.not_nil!).should eq("First")

      # Second annotation
      ann2 = arena[program.roots[1]]
      ann2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Annotation)
      String.new(ann2.annotation_name.not_nil!).should eq("Second")

      # Third annotation
      ann3 = arena[program.roots[2]]
      ann3.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Annotation)
      String.new(ann3.annotation_name.not_nil!).should eq("Third")
    end

    it "parses annotation with body (Phase 92A: body skipped)" do
      source = <<-CRYSTAL
      annotation MyAnnotation
        getter value : String
        getter count : Int32
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      annotation_node = arena[program.roots[0]]
      annotation_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Annotation)
      String.new(annotation_node.annotation_name.not_nil!).should eq("MyAnnotation")

      # Phase 92A: Body is skipped/ignored for now
      # Body parsing will be Phase 92B if needed
    end

    it "parses annotation before class definition" do
      source = <<-CRYSTAL
      annotation Deprecated
      end

      class Foo
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      # First root is annotation
      ann = arena[program.roots[0]]
      ann.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Annotation)

      # Second root is class
      cls = arena[program.roots[1]]
      cls.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)
    end
  end
end
