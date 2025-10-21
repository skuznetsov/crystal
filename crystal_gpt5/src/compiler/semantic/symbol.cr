require "../frontend/ast"

module CrystalGPT5
  module Compiler
    module Semantic
      alias ExprId = Frontend::ExprId

      abstract class Symbol
        getter name : String
        getter node_id : ExprId

        def initialize(@name : String, @node_id : ExprId)
        end
      end

      class MacroSymbol < Symbol
        getter body : ExprId
        getter params : Array(String)?

        def initialize(name : String, node_id : ExprId, @body : ExprId, @params : Array(String)? = nil)
          super(name, node_id)
        end
      end

      class MethodSymbol < Symbol
        getter params : Array(Frontend::Parameter)
        getter return_annotation : String?
        getter scope : SymbolTable

        def initialize(name : String, node_id : ExprId, *, params : Array(Frontend::Parameter) = [] of Frontend::Parameter, return_annotation : String? = nil, scope : SymbolTable)
          super(name, node_id)
          @params = params
          @return_annotation = return_annotation
          @scope = scope
        end
      end

      class ClassSymbol < Symbol
        getter scope : SymbolTable
        getter superclass_name : String?

        def initialize(name : String, node_id : ExprId, *, scope : SymbolTable, superclass_name : String? = nil)
          super(name, node_id)
          @scope = scope
          @superclass_name = superclass_name
        end
      end

      class VariableSymbol < Symbol
        getter declared_type : String?

        def initialize(name : String, node_id : ExprId, declared_type : String? = nil)
          super(name, node_id)
          @declared_type = declared_type
        end
      end

      # Test-only placeholder symbol for SymbolTable specs
      class DummySymbol < Symbol
        getter metadata : String

        def initialize(name : String, node_id : ExprId, @metadata : String)
          super(name, node_id)
        end
      end
    end
  end
end
