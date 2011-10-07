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
      raise "what is this?" unless s.sexp[0] == :iter && s.sexp[1][0] == :call && s.sexp[1][1] == nil && s.sexp[1][2] == :proc && s.sexp[1][3][0] == :arglist

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

    # Compile self
    #
    # * +return_variable+ - The return variable. Can either be a symbol representing the variable name or nil to skip variable assigning.
    # * +replace+         - A list of variables in need of a new unique name or replacement with inlined code
    #
    def compile_with_return_to_var(return_variable, replace = {})
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
              replace[args[i]] = Replacement.new(:sexp => Sexp.new(:block,*code), :inline => true, :rule => rule)
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
        replace_variable_references(code,v,k)
      end

      return *args_code + [code]
    end

    # Recurcively replace all references in a code section
    #
    # * +code+        - The code haystack to search and replace in
    # * +replacement+ - The replacement code. Either a Sexp (containing code to inline) or a symbol
    # * +needle+      - The search needle
    #
    def replace_variable_references(code,replacement,needle)

      #inline = replacement.kind_of?(Sexp)

      case code[0]
      when :lasgn
        code[1]=replacement.sexp if code[1] == needle
      when :lvar
        if code[1] == needle
          unless replacement.inline?
            code[1]=replacement.sexp
          end
        end
      when :call
        code[2]=replacement.sexp if code[2] == needle
      when :lvar
        code[1]=replacement.sexp if code[1] == needle
      end
      # inlining requires complex code:
      if replacement.inline? && [:iter, :block].include?(code[0])
        # we have a inline and a block, replace any references with the sexp
        code[1..-1].each_with_index do |h,i|
          if h && h.kind_of?(Sexp) && h == Sexp.new(:lvar, needle)
            # inline references like s(:lvar, :needle)
            # indicates a call to the needle, thus code wants to inline
            h[0] = replacement.sexp[0]
            h[1] = replacement.sexp[1]
          elsif h && h.kind_of?(Sexp) && @named_args.has_key?(needle) &&
              Reduction.parse(@named_args[needle]).named_args.select{ |k,v|
                h == Sexp.new(:call, Sexp.new(:lvar, needle), :[], Sexp.new(:arglist, Sexp.new(:lit, k)))
              }.size == 1
            # code is asking for a injection of one of the argument's with:
            #  s(:call, s(:lvar, :needle), :[], s(:arglist, s(:lit, :argumen)))
            # which in ruby looks like:
            #  needle[:argument]
            # which again is the way we support calling arguments of the neede
            arg = h[3][1][1]
            sexy = Marshal.load(Marshal.dump(Reduction.parse(Reduction.parse(@named_args[needle]).named_args[arg]).sexp)) # sexp handling is not clean cut
            code[i+1] = sexy[3]
          else
            replace_variable_references(h,replacement,needle) if h && h.kind_of?(Sexp)
          end
        end
      else
        code[1..-1].each do |h|
          replace_variable_references(h,replacement,needle) if h && h.kind_of?(Sexp)
        end
      end
    end

    def to_rexp
      raise "hell" if returns.kind_of?(Array)
      "{#{returns}:#{reduction_id}}"
    end
  end

end
