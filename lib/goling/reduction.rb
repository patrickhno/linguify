# encoding: utf-8

module Goling

  class Reduction

    attr_accessor :returns, :location, :line, :regexp, :args, :sexp, :rule_args, :from, :reduction_id

    @@reductions = []

    def initialize params
      @returns  = params[:returns]
      @location = params[:location]
      @line     = params[:line]
      @regexp   = params[:regexp]
      @rule_args= @regexp.split(')').map{ |sub| sub.split('(')[1] }.select{ |v| v }
      @args     = params[:args]
      @sexp     = params[:sexp]
      @reduction_id = @@reductions.size
      @@reductions << self
    end

    def self.parse str
      if /^{(?<return>[^:]*):(?<rid>[0-9]+)}$/ =~ str
        @@reductions[rid.to_i]
      elsif /^(?<return>[^:]*):(?<rid>[0-9]+)$/ =~ str
        @@reductions[rid.to_i]
      else
  ap str
  raise "hell"
      end
    end

    def compile_with_return_to_var(return_variable, replace = {})
      s = Marshal.load(Marshal.dump(self)) # sexp handling is not clean cut
      raise "what is this?" unless s.sexp[0] == :iter && s.sexp[1][0] == :call && s.sexp[1][1] == nil && s.sexp[1][2] == :proc && s.sexp[1][3][0] == :arglist

      block_args = s.sexp[2]
      #ap "block args: #{block_args}"
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
          unless s.rule_args.size == args.size
            raise "number of arguments in reduction rule (#{s.rule_args}) do not match the number of block arguments (#{args.size}) at #{s.location}:#{s.line}"
          end
          # args[] now has the symbolized argument names of the code block

          args_code = []
          s.args.each_with_index do |arg,i|
            if /^{(?<ret>[^:]*):(?<n>[0-9]+)}$/ =~ arg
              args_code += Reduction::parse(arg).compile_with_return_to_var("#{ret}_#{n}".to_sym,replace)
            elsif /^[0-9]+$/ =~ arg
              args_code << Sexp.new(:lasgn, args[i], Sexp.new(:lit, arg.to_i))
            else
              raise "hell"
            end
          end
          s.args.each_with_index do |arg,i|
            if /^{(?<ret>[^:]*):(?<n>[0-9]+)}$/ =~ arg
              replace[args[i]] = "#{ret}_#{n}".to_sym
            end
          end

          if s.sexp[3][0] == :block
            if return_variable
              code = Sexp.new(:lasgn, return_variable, Sexp.new(:block,
                  *(s.sexp[3][1..-1].map{ |s| s.dup })
                  )
              )
            else
              code = s.sexp[3].dup
            end
            replace.each do |k,v|
              replace_variable_references(code,v,k)
            end
            return *args_code + [code]
          else
            if return_variable
              code = Sexp.new(:lasgn, return_variable, s.sexp[3].dup)
            else
              code = s.sexp[3].dup
            end
            replace.each do |k,v|
              replace_variable_references(code,v,k)
            end
            return *args_code + [code]
          end
        else
          raise "number of arguments in reduction rule do not match the number of block arguments" unless s.rule_args.size == 0
          # code block without arguments
          if s.sexp[3][0] == :block
            if return_variable
              code = Sexp.new(:lasgn, return_variable, Sexp.new(:block,
                *(s.sexp[3][1..-1].map{ |s| s.dup })
                )
              )
            else
              code = s.sexp[3].dup
            end
            replace.each do |k,v|
              replace_variable_references(code,v,k)
            end
            [code]
          else
            if return_variable
              code = Sexp.new(:lasgn, return_variable, s.sexp[3].dup)
            else
              code = s.sexp[3].dup
            end
            replace.each do |k,v|
              replace_variable_references(code,v,k)
            end
            [code]
          end
        end
    end

    def replace_variable_references(code,replacement,needle)
      case code[0]
      when :lasgn
        code[1]=replacement if code[1] == needle
      when :lvar
        code[1]=replacement if code[1] == needle
      when :call
        code[2]=replacement if code[2] == needle
      when :lvar
        code[1]=replacement if code[1] == needle
      end
      code[1..-1].each do |h|
        replace_variable_references(h,replacement,needle) if h && h.kind_of?(Sexp)
      end
    end

    def to_rexp
      "{#{returns}:#{reduction_id}}"
    end
  end

end
