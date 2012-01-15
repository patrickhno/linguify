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

require 'sourcify'
require 'linguify/translators/javascript'

module Linguify

  class Linguified

    attr_accessor :proc, :sentence

    # Lingquify a sentence
    #
    # @param [ String ] string A plain English string, or a plain English string with reductions in it.
    # @param [ Binding ] binding See +Kernel#eval+
    #
    def initialize str,bind

      #
      # reduction loop
      #
      @sentence = str.dup
      @bind = bind
      loop do
        rule = find_rule(str)

        reduction = rule[:proc].to_reduction :returns  => rule[:result],
                                             :lang     => rule[:lang],
                                             :inline   => rule[:inline],
                                             :regexp   => rule[:match].inspect,
                                             :args     => rule[:match].match(str).to_a

        str = Linguified.reduce_string(str,rule[:match],reduction.to_rexp)
        break if /^{:[0-9]*}$/ =~ str
      end

      @merged_code = []

      #
      # successfully reduced entire string, compile it
      #

      code = Reduction::parse(str).compile

      #if @dispatch_exceptions
      #  @sexy = Sexp.debug_envelope(code)
      #else
        @sexy = Sexp.lambda_envelope(code)
      #end

      # let ruby compile a proc out of the actual code
      # the trampoline function will receive the compiled Proc
      @@me = self
      eval to_ruby(
          Sexp.new(:call,
            Sexp.new(:colon2, Sexp.new(:const, :Linguify), :Linguified), :trampoline, Sexp.new(:arglist, Sexp.new(:lvar, :code))
          )
        ),bind
    end

    # Reduce a string with a matching reduction expression
    #
    # @param [ String ] the sentence to reduce   (haystack)
    # @param [ Regexp ] the reduction expression (search needle)
    # @param [ String ] the replacement
    # @returns [ String ] the reduced string
    #
    def self.reduce_string str,match_expression,reduction
      match = match_expression.match(str).to_a
      needle = match.first
      splitted = Linguified.informative_split(str,needle)
      if match.size == 1
        prev = ' '
        i = -1
        splitted.map! do |split|
          prev = splitted[i] if i>=0
          nxt  = splitted[i+2] || ' '
          i += 1
          if split.kind_of?(Symbol)
            if prev[-1] == ' ' and nxt[0] == ' '
              reduction
            else
              needle
            end
          else
            split
          end
        end
        splitted.join
      else
        splitted.map{ |split| split.kind_of?(Symbol) ? reduction : split }.join
      end
    end

    # Split a string by given search needle into an array with split indicators
    #
    # @param [ String ] the string to search     (haystack)
    # @param [ String ] needle                   (search needle)
    # @returns [ Array ] the remaining pieces and needle tags
    #
    def self.informative_split str,needle
      splitted = str.split(needle)
      if str.index(needle) > 0
        splitted.map{ |m| [m,:needle] }.flatten[0..splitted.size+str.scan(needle).size-1]
      else
        if splitted.size > 0
          splitted.map{ |m| [m,:needle] }.flatten[1..-2]
        elsif str == needle
          [ :needle ]
        else
          []
        end
      end
    end

    # Test if a informative split contains needles on word boundaries
    #
    # @param [ Array ] the splitted string
    # @returns [ Boolean ] true if so
    #
    def self.has_needle_on_word_boundary? splitted
      return true if splitted.size == 1 and splitted.first == :needle

      splitted.each_with_index do |split,i|
        if split.kind_of? String
          word_bound = i == 0 ? split[-1] == ' ' : split[0] == ' ' || split[-1] == ' '
          return true if word_bound
        end
      end
      false
    end

    # Find a reduction rule for the string
    #
    # @param [ String ] string A plain English string, or a plain English string with reductions in it.
    #
    def find_rule str
      found = Linguify.rules.select do |rule|
        if rule[:match] =~ str
          # ok, it matched, but only alow matches with word boundaries
          match = rule[:match].match(str).to_a
          needle = match.first
          Linguified.has_needle_on_word_boundary? Linguified.informative_split(str,needle)
        else
          false
        end
      end
      raise "no step definition for #{str}" if found.size == 0
      found[0]
    end

    def to_sexp
      @sexy
    end

    def to_ruby additional=nil
      clone = Marshal.load(Marshal.dump(@sexy)) # sexy is not cleanly duplicated
      clone << additional if additional
      Ruby2Ruby.new.process(clone)
    end
    
    def run
      begin
        @proc.call
      rescue Exception => e
        $stderr.puts e
      end
    end
  
    def register_code code
      @proc = code
    end

    def self.trampoline code
      @@me.register_code code
    end
  
    def self.cache
      @@cache ||= {}
    end

  end

end
