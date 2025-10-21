require "./span"
require "./parser/diagnostic"

module CrystalGPT5
  module Compiler
    module Frontend
      module DiagnosticFormatter
        extend self

        def format(source : String?, diagnostic : Diagnostic) : String
          span = diagnostic.span
          range = format_range(span)
          base = String.build do |io|
            io << range << ' ' << diagnostic.message
          end

          return base unless source && span

          snippet_lines = extract_lines(source, span)
          return base if snippet_lines.empty?

          underline_lines = build_underlines(snippet_lines, span)
          String.build do |io|
            io << base << '\n'
            snippet_lines.join('\n', io)
            io << '\n'
            underline_lines.join('\n', io)
          end
        end

        private def format_range(span : Span) : String
          "#{span.start_line}:#{span.start_column}-#{span.end_line}:#{span.end_column}"
        end

        private def extract_lines(source : String, span : Span) : Array(String)
          lines = source.lines
          start_index = span.start_line - 1
          end_index = span.end_line - 1
          return [] unless start_index >= 0 && end_index < lines.size
          lines[start_index..end_index]
        end

        private def build_underlines(lines : Array(String), span : Span) : Array(String)
          return [] if lines.empty?
          count = lines.size

          lines.each_with_index.map do |line, index|
            if count == 1
              underline_segment(line, span.start_column, span.end_column)
            elsif index == 0
              underline_segment(line, span.start_column, line.size + 1)
            elsif index == count - 1
              underline_segment(line, 1, span.end_column)
            else
              underline_segment(line, 1, line.size + 1)
            end
          end
        end

        private def underline_segment(line : String, start_column : Int32, end_column : Int32) : String
          length = line.size
          start_index = (start_column - 1).clamp(0, length)
          end_index = (end_column - 1).clamp(start_index, length)
          caret_count = end_index - start_index
          caret_count = 1 if caret_count <= 0
          available = length - start_index
          if available <= 0
            start_index = length
            available = 0
          end
          if available > 0 && caret_count > available
            caret_count = available
          end
          caret_count = 1 if caret_count <= 0
          String.build do |io|
            io << ' ' * start_index
            io << '^' * caret_count
          end
        end
      end
    end
  end
end
