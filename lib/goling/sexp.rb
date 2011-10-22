# encoding: utf-8

class Sexp < Array

  # Recurcively replace all references in a code section
  #
  # * +code+        - The code haystack to search and replace in
  # * +replacement+ - The replacement code. Either a Sexp (containing code to inline) or a symbol
  # * +needle+      - The search needle
  #
  def replace_variable_references!(replacement,needle,named_args="")
    
    case sexp_type
    when :lasgn
      self[1]=replacement.sexp if self[1] == needle
    when :lvar
      if self[1] == needle
        unless replacement.inline?
          self[1]=replacement.sexp
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
            Goling::Reduction.parse(named_args[needle]).named_args.select{ |k,v|
              h == Sexp.new(:call, Sexp.new(:lvar, needle), :[], Sexp.new(:arglist, Sexp.new(:lit, k)))
            }.size == 1
          # code is asking for a injection of one of the argument's with:
          #  s(:call, s(:lvar, :needle), :[], s(:arglist, s(:lit, :argumen)))
          # which in ruby looks like:
          #  needle[:argument]
          # which again is the way we support calling arguments of the neede
          arg = h[3][1][1]
          sexy = Marshal.load(Marshal.dump(Goling::Reduction.parse(Goling::Reduction.parse(named_args[needle]).named_args[arg]).sexp)) # sexp handling is not clean cut
          self[i+1] = sexy[3]
        else
          h.replace_variable_references!(replacement,needle,named_args) if h && h.kind_of?(Sexp)
        end
      end
    else
      self[1..-1].each do |h|
        h.replace_variable_references!(replacement,needle,named_args) if h && h.kind_of?(Sexp)
      end
    end
  end

end

