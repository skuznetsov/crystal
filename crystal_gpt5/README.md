# Crystal GPT-5 Compiler Initiative

This workspace explores a ground-up redesign of the Crystal compiler aligned with
the goals we discussed:

- **Fast edit-compile loop** via fully incremental front-end.
- **High-quality native code** using a typed SSA mid-end with LLVM as a backend target.
- **Bootstrap in Crystal** so the new compiler can eventually self-host.

## Milestones

1. **Front-end spike** – streaming lexer/parser, persistent AST.
2. **Semantic core** – modular type checker with dependency tracking.
3. **Typed SSA IR** – mid-level representation to drive optimizations.
4. **Backends** – LLVM first, followed by pluggable alternatives.
5. **Runtime & tooling** – lightweight runtime, LSP integration, build caching.

We start with scaffolding and gradually replace components with production-ready
implementations. Every step should keep the repo buildable so we can automate
validation from the earliest stages.

