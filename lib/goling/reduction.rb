# encoding: utf-8

module Goling
  
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
      # args[] now has the symbolized argument names of the code block
      @named_args = Hash[*args.zip(@args).flatten] if args
      @named_args ||= {}
    end

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

    # Compile self
    #
    # * +return_variable+ - The return variable. Can either be a symbol representing the variable name or nil to skip variable assigning.
    # * +replace+         - A list of variables in need of a new unique name or replacement with inlined code
    #
    def compile_with_return_to_var(return_variable=nil, replace = {})
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
            code = red.compile_with_return_to_var(nil,replace)
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
              code = red.compile_with_return_to_var(nil,replace)
              replace[args[i]] = Replacement.new(:sexp => Sexp.new(:block,*code), :inline => true)
            else
              code = red.compile_with_return_to_var("#{ret}_#{n}".to_sym,replace)
              args_code += code
              replace[args[i]] = Replacement.new(:sexp => "#{ret}_#{n}".to_sym)
            end
          end
        elsif /^[0-9]+$/ =~ arg
          # got a number argument, stuff it in a integer variable
          args_code << Sexp.new(:lasgn, args[i], Sexp.new(:lit, arg.to_i))
        else
          raise "hell"
        end
      end

      if return_variable
        if s.sexp[3][0] == :block
          code = Sexp.new(:lasgn, return_variable,
            Sexp.new(:block,
              *(s.sexp[3][1..-1].map{ |s| s.dup })
            )
          )
        else
          code = Sexp.new(:lasgn, return_variable, s.sexp[3].dup)
        end
      else
        code = s.sexp[3].dup
      end

      replace.each do |k,v|
        code.replace_variable_references!(v,k,@named_args)
      end

      return *args_code + [code]
    end

    def to_rexp
      raise "hell" if returns.kind_of?(Array)
      "{#{returns}:#{reduction_id}}"
    end
  end

end
