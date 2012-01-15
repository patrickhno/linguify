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

module Linguify
  
  class Replacement
    attr_reader :sexp

    def initialize args
      @sexp   = args[:sexp]
      @inline = args[:inline] || false
    end
    
    def inline?
      @inline
    end
  end

  class Reduction

    attr_accessor :returns, :location, :line, :regexp, :args, :sexp, :rule_args, :from, :reduction_id, :lang, :inline, :named_args

    @@reductions = []

    def initialize params
      @returns  = params[:returns]
      @lang     = params[:lang]
      @inline   = params[:inline]
      @location = params[:location]
      @line     = params[:line]
      @regexp   = params[:regexp]
      @rule_args= @regexp.split(')').map{ |sub| sub.split('(')[1] }.select{ |v| v }
      @args     = params[:args]
      @sexp     = params[:sexp]
      @reduction_id = @@reductions.size
      determine_arguments
      @@reductions << self
    end

    # Extract the arguments from the code block of this Reduction.
    #
    # @returns [ Hash ] Key valye pairs of symbolized variable names and the reduction reference.
    #
    def determine_arguments
      s = Marshal.load(Marshal.dump(self)) # sexp handling is not clean cut
      raise "what is this?" unless s.sexp.sexp_type == :iter && s.sexp[1].sexp_type == :call && s.sexp[1][1] == nil && s.sexp[1][2] == :proc && s.sexp[1][3].sexp_type == :arglist

      block_args = s.sexp[2]
      if block_args
        if block_args[0]==:lasgn
          # single argument
          args = [block_args[1]]
        elsif block_args[0]==:masgn
          # multiple arguments
          args = block_args[1]
          raise "unsupported argument type #{args}" unless args[0]==:array
          args = args[1..-1].map{ |arg|
            raise "unsupported argument type #{arg}" unless arg[0]==:lasgn
            arg[1]
          }
        else
          raise "unsupported argument type #{args}"
        end
      end

      # maybe we can fix the input so we don't have to repair it here?
      @args = @args[-args.size..-1] if args and args.size != @args.size

      @named_args = Hash[*args.zip(@args[-args.size..-1]).flatten] if args
      @named_args ||= {}
    end

    # Parse the string and return its reduction rule.
    #
    # @returns [ Reduction ] The reduction rule of the string.
    #
    def self.parse str
      if /^{(?<return>[^:]*):(?<rid>[0-9]+)}$/ =~ str
        @@reductions[rid.to_i]
      elsif /^(?<return>[^:]*):(?<rid>[0-9]+)$/ =~ str
        @@reductions[rid.to_i]
      else
        raise "hell #{str}"
      end
    end
    
    def compile
      compile_with_return_to_var
    end

    def allocate_variable name,not_in
      n = 0
      begin
        var = "#{name}_#{n}".to_sym
        n += 1
      end while not_in.select{ |sexp| sexp.variable_exists?(var) }.size > 0
      var
    end

    # Compile self
    #
    # @param [ Symbol,nil ] return_variable The variable in the code wanting the result.
    # @param [ Array<Symbol,Sexp>] replacement A list of variables in need of a new unique name or replacement with inlined code
    # @returns [ Array<Sexp> ] the compiled code
    #
    def compile_with_return_to_var params={}
      replace = params[:replace] || {}

      s = Marshal.load(Marshal.dump(self)) # sexp handling is not clean cut
      args = @named_args.keys
      # args[] now has the symbolized argument names of the code block

      args_code = []
      s.args.each_with_index do |arg,i|
        if /^{(?<ret>[^:]*):(?<n>[0-9]+)}$/ =~ arg
          # got a argument that referes to a reduction
          # pseudo allocate a return variable name and compile the reduction
          red = Reduction::parse(arg)
          if red.lang != lang && red.lang == :js && lang == :ruby
            # paste javascript code into a ruby variable
            code = red.compile_with_return_to_var :replace => replace
            clone = Marshal.load(Marshal.dump(code)) # code is not cleanly duplicated
            code = Sexp.new(:iter,Sexp.new(:call, nil, :lambda, Sexp.new(:arglist)), nil,
              Sexp.new(:block,
                *clone
              )
            )
            code = Ruby2Js.new.process(code)
            code = [Sexp.new(:lasgn, args[i], Sexp.new(:lit, code))]
            args_code += code
          else
            raise "trying to reference #{red.lang} code in #{lang} code" if red.lang != lang
            if red.inline
              code = red.compile_with_return_to_var :replace => replace
              replace[args[i]] = Replacement.new(:sexp => Sexp.new(:block,*code), :inline => true)
            else
              var = allocate_variable(ret,[*args_code,sexp])
              code = red.compile_with_return_to_var :return_variable => var, :replace => replace
              args_code += code
              replace[args[i]] = Replacement.new(:sexp => var)
            end
          end
        elsif /^[0-9]+$/ =~ arg
          # got a number argument, stuff it in a integer variable
          args_code << Sexp.new(:lasgn, args[i], Sexp.new(:lit, arg.to_i))
        else
          # got a string
          replace[args[i]] = Replacement.new(:sexp => Sexp.new(:str, arg)) if args[i]
        end
      end

      if params[:return_variable]
        if s.sexp[3][0] == :block
          code = Sexp.new(:lasgn, params[:return_variable],
            Sexp.new(:block,
              *(s.sexp[3][1..-1].map{ |s| s.dup })
            )
          )
        else
          code = Sexp.new(:lasgn, params[:return_variable], s.sexp[3].dup)
        end
      else
        code = s.sexp[3].dup
      end

      replace.each do |k,v|
        code.replace_variable_references! :replacement => v, :needle => k, :named_args => @named_args
      end

      return *args_code + [code]
    end

    # Get the reduction reference for this Reduction.
    #
    # @returns [ String ] A unique string reference refering to this Reduction.
    #
    def to_rexp
      raise "hell" if returns.kind_of?(Array)
      "{#{returns}:#{reduction_id}}"
    end
  end

end
