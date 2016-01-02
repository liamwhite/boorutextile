module Textile
  class Renester
    # An asterisk could just be part of the text, or it could have matching
    # pair somewhere and be considered a bold node.
    # This method resolves that ambiguity for the parser by reprocessing the
    # tokens to determine if they nest validly.
    def self.renest(tokens)
      output = []
      return output if tokens.empty?

      while idx1 = tokens.index(&:nesting)
        tok = tokens[idx1].nesting

        # Find the next one
        idx2 = tokens[idx1+1..-1].index {|t| t.type == tok[:end] }

        if idx2
          output.concat tokens.shift(idx1)                       # push outside tokens
          output.push   tokens.shift.tap{|t| t.type = tok[:op] } # convert
          output.concat renest(tokens.shift(idx2))               # splice inside portion
          output.push   tokens.shift.tap{|t| t.type = tok[:op] } # convert
        else
          # Shift everything up to and including this match
          output.concat tokens.shift(idx1+1)
        end
      end

      # add anything else
      output.concat tokens
    end
  end
end
