# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

include TwitterCldr::Parsers
include TwitterCldr::Tokenizers

module TwitterCldr
  module Shared
    class BreakIterator

      # We ask for locale here because of locale-specific segmentation
      # tailorings, which currently aren't supported. This parameter is ignored.
      def initialize(locale = :root)
        @locale = locale
      end

      def each_sentence(str, &block)
        each_boundary(str, "sentence", &block)
      end

      private

      def boundary_name_for(str)
        str.gsub(/(?:^|\_)([A-Za-z])/) { |s| $1.upcase } + "Break"
      end

      def each_boundary(str, boundary_type)
        if block_given?
          rules = compile_rules_for(boundary_type)
          current = ""
          current_offset = 0

          str.each_char do |c|
            current << c

            rules.each_with_index do |rule, idx|
              if match = rule.match(current)
                if rule.boundary_symbol == :break
                  yield current[0..(match.boundary_offset - 1)]
                  current = current[match.boundary_offset..-1]
                  current_offset += match.boundary_offset
                end
              end
            end
          end

          if current_offset < str.size
            yield current
          end
        else
          to_enum(__method__, str, boundary_type)
        end
      end

      def compile_rules_for(boundary_type)
        rule_cache[boundary_type] ||= begin
          boundary_name = boundary_name_for(boundary_type)
          boundary_data = resource_for(boundary_name)
          @symbol_table = symbol_table_for(boundary_data)
          rules_for(boundary_data, @symbol_table)
        end
      end

      def rule_cache
        @rule_cache ||= {}
      end

      def symbol_table_for(boundary_data)
        table = SymbolTable.new
        boundary_data[:variables].each do |variable|
          id = variable[:id].to_s
          tokens = segmentation_tokenizer.tokenize(variable[:value])
          # note: variables can be redefined (add replaces if key already exists)
          table.add(id, resolve(tokens, table))
        end
        table
      end

      def resolve(tokens, symbol_table)
        tokens.inject([]) do |ret, token|
          if token.type == :variable
            ret += symbol_table.fetch(token.value)
          else
            ret << token
          end
          ret
        end
      end

      def rules_for(boundary_data, symbol_table)
        boundary_data[:rules].map do |rule|
          r = segmentation_parser.parse(
            segmentation_tokenizer.tokenize(add_anchors(rule[:value])), {
              :symbol_table => symbol_table
            }
          )

          r.string = rule[:value]
          r.id = rule[:id]
          r
        end
      end

      # helps ensure we only find exact matches
      def add_anchors(val)
        val # "^#{val}$"
      end

      def segmentation_tokenizer
        @@segmentation_tokenizer ||= SegmentationTokenizer.new
      end

      def segmentation_parser
        @@segmentation_parser ||= SegmentationParser.new
      end

      # tailoring would probably be done here
      def resource_for(boundary_name)
        root_resource[:segments][boundary_name.to_sym]
      end

      def root_resource
        @@root_resource ||= TwitterCldr.get_resource("shared", "segments_root")
      end

    end
  end
end
