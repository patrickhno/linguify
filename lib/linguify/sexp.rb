# encoding: utf-8

# Copyright (c) 2011-2012 Patrick Hanevold.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class Sexp < Array

  # Recurcively replace all references in a code section
  #
  # @param [ Sexp, Symbol ] replacement The replacement code. Either a Sexp (containing code to inline) or a symbol
  # @param [ Sexp ] needle The search needle
  # @param [ Hash ] named_args The arguments of the code block
  #
  def replace_variable_references! params

    replacement = params[:replacement]
    needle      = params[:needle]
    named_args  = params[:named_args] || ''

    case sexp_type
    when :lasgn
      self[1]=replacement.sexp if self[1] == needle
    when :lvar
      if self[1] == needle
        unless replacement.inline?
          if replacement.sexp[0] == :str
            self[0] = :str
            self[1]=replacement.sexp[1]
          else
            self[1]=replacement.sexp
          end
        end
      end
    when :call
      self[2]=replacement.sexp if self[2] == needle
    when :lvar
      self[1]=replacement.sexp if self[1] == needle
    end
    # inlining requires complex code:
    if replacement.inline? && [:iter, :block].include?(sexp_type)
      # we have a inline and a block, replace any references with the sexp
      self[1..-1].each_with_index do |h,i|
        if h && h.kind_of?(Sexp) && h == Sexp.new(:lvar, needle)
          # inline references like s(:lvar, :needle)
          # indicates a call to the needle, thus code wants to inline
          h[0] = replacement.sexp[0]
          h[1] = replacement.sexp[1]
        elsif h && h.kind_of?(Sexp) && named_args.has_key?(needle) &&
            Linguify::Reduction.parse(named_args[needle]).named_args.select{ |k,v|
              h == Sexp.new(:call, Sexp.new(:lvar, needle), :[], Sexp.new(:arglist, Sexp.new(:lit, k)))
            }.size == 1
          # code is asking for a injection of one of the argument's with:
          #  s(:call, s(:lvar, :needle), :[], s(:arglist, s(:lit, :argumen)))
          # which in ruby looks like:
          #  needle[:argument]
          # which again is the way we support calling arguments of the neede
          arg = h[3][1][1]
          sexy = Marshal.load(Marshal.dump(Linguify::Reduction.parse(Linguify::Reduction.parse(named_args[needle]).named_args[arg]).sexp)) # sexp handling is not clean cut
          self[i+1] = sexy[3]
        else
          h.replace_variable_references!(:replacement => replacement, :needle => needle, :named_args => named_args) if h && h.kind_of?(Sexp)
        end
      end
    else
      self[1..-1].each do |h|
        h.replace_variable_references!(:replacement => replacement, :needle => needle, :named_args => named_args) if h && h.kind_of?(Sexp)
      end
    end
  end

  # Envelope a Sexp in a lambda
  #
  # @param [ Sexp ] code The Sexp to envelope
  # @returns [ Sexp ] result The enveloped sexp
  #
  def self.lambda_envelope code
    # and wrap it up in a lambda envelope for the sexp representation
    Sexp.new(:block,
      Sexp.new(:lasgn,:code, Sexp.new(:iter,
        Sexp.new(:call, nil, :lambda, Sexp.new(:arglist)), nil,
          Sexp.new(:block,
            *code
          )
        )
      )
    )
  end

  def variable_exists? needle
    case sexp_type
    when :lasgn
      self[1] == needle
    when :lvar
      self[1] == needle
    when :call
      self[2] == needle
    when :lvar
      self[1] == needle
    else
      self[1..-1].each do |h|
        if h && h.kind_of?(Sexp)
          return true if h.variable_exists?(needle)
        end
      end
      false
    end
  end

  ##
  ## currently not in use
  ## 1.9.2 p180 doesn't give us a backtrace from the other side
  ##
  # Envelope a Sexp in the debug envelope
  # which basicly dispatch exceptions into our unitverse
  #
  # @param [ Sexp ] code The Sexp to envelope
  # @returns [ Sexp ] result The enveloped sexp
  #
  #def self.debug_envelope code
  #  Sexp.new(:block,
  #    Sexp.new(:lasgn,:code, Sexp.new(:iter,
  #      Sexp.new(:call, nil, :lambda, Sexp.new(:arglist)), nil,
  #        Sexp.new(:rescue,
  #          Sexp.new(:block,*code),
  #          Sexp.new(:resbody,
  #            Sexp.new(:array, Sexp.new(:const, :Exception), Sexp.new(:lasgn, :e, Sexp.new(:gvar, :$!))),
  #            Sexp.new(:call, Sexp.new(:const, :Linguify), :exception, Sexp.new(:arglist, Sexp.new(:lvar, :e))))))))
  #end

  def find needle
    res = []
    res << self if sexp_type == needle
    case sexp_type
    when :lasgn
      self[1] == needle
    when :lvar
      self[1] == needle
    when :call
      self[2] == needle
    when :lvar
      self[1] == needle
    else
      self[1..-1].each do |h|
        if h && h.kind_of?(Sexp)
          res += h.find(needle)
        end
      end
    end
    res
  end

  def self.inline_keyword_inlined! code
    inlines = Sexp.from_array(code).find(:call).select{ |call| call[1] == nil && call[2] == :inline }
    inlines.each do |inline|
      raise "Im lost, dont know what this is (yet)" unless inline[3].sexp_type == :arglist
      raise "Im lost, dont know what this is (yet)" unless inline[3].size == 2
      raise "Im lost, dont know what this is (yet)" unless inline[3][1].sexp_type == :lvar
      var = inline[3][1][1]

      assignments = []
      code.each_with_index do |expression,n|
        if expression.sexp_type == :lasgn and expression[1] == var
          assignments << n
        end
      end
      raise "this should never happen (yes, really!)" unless assignments.size == 1

      code_block = code[assignments.first]
      code.delete_at(assignments.first)

      # now inject code
      inline.clear
      inline[0] = code_block[0]
      inline[1] = code_block[1]
      inline[2] = code_block[2]
    end
  end

end

