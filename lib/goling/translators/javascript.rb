
require 'sexp_processor'

class Ruby2Js < SexpProcessor
  VERSION = '1.3.1'
  LINE_LENGTH = 78

  BINARY = [:<=>, :==, :<, :>, :<=, :>=, :-, :+, :*, :/, :%, :<<, :>>, :**]

  ##
  # Nodes that represent assignment and probably need () around them.
  #
  # TODO: this should be replaced with full precedence support :/

  ASSIGN_NODES = [
                  :dasgn,
                  :flip2,
                  :flip3,
                  :lasgn,
                  :masgn,
                  :attrasgn,
                  :op_asgn1,
                  :op_asgn2,
                  :op_asgn_and,
                  :op_asgn_or,
                  :return,
                  :if, # HACK
                 ]

  def initialize
    super
    @indent = "  "
    self.auto_shift_type = true
    self.strict = true
    self.expected = String

    @calls = []

    # self.debug[:defn] = /zsuper/
  end

  def parenthesize exp
    case self.context[1]
    when nil, :scope, :if, :iter, :resbody, :when, :while, :until then
      exp
    else
      "(#{exp})"
    end
  end

  def indent(s)
    s.to_s.split(/\n/).map{|line| @indent + line}.join("\n")
  end

  def cond_loop(exp, name)
    cond = process(exp.shift)
    body = process(exp.shift)
    head_controlled = exp.shift

    body = indent(body).chomp if body

    code = []
    if head_controlled then
      code << "#{name}(#{cond}){"
      code << body if body
      code << "}"
    else
      code << "begin"
      code << body if body
      code << "end #{name} #{cond}"
    end
    code.join("\n")
  end

  def process_and(exp)
    parenthesize "#{process exp.shift} and #{process exp.shift}"
  end

  def process_arglist(exp) # custom made node
    code = []
    until exp.empty? do
      code << process(exp.shift)
    end
    code.join ', '
  end

  def process_args(exp)
    args = []

    until exp.empty? do
      arg = exp.shift
      case arg
      when Symbol then
        args << arg
      when Array then
        case arg.first
        when :block then
          asgns = {}
          arg[1..-1].each do |lasgn|
            asgns[lasgn[1]] = process(lasgn)
          end

          args.each_with_index do |name, index|
            args[index] = asgns[name] if asgns.has_key? name
          end
        else
          raise "unknown arg type #{arg.first.inspect}"
        end
      else
        raise "unknown arg type #{arg.inspect}"
      end
    end

    return "(#{args.join ', '})"
  end

  def process_array(exp)
    "[#{process_arglist(exp)}]"
  end
  
  def process_attrasgn(exp)
    receiver = process exp.shift
    name = exp.shift
    args = exp.empty? ? nil : exp.shift

    case name
    when :[]= then
      rhs = process args.pop
      "#{receiver}[#{process(args)}] = #{rhs}"
    else
      name = name.to_s.sub(/=$/, '')
      if args && args != s(:arglist) then
        "#{receiver}.#{name} = #{process(args)}"
      end
    end
  end

  def process_block(exp)
    result = []
    
    exp << nil if exp.empty?
    until exp.empty? do
      code = exp.shift
      if code.nil? or code.first == :nil then
        result << "# do nothing\n"
      else
        result << process(code)
      end
    end

    result = parenthesize result.join ";\n"
    result += ";\n" unless result.start_with? "("

    return result
  end

  def process_break(exp)
    val = exp.empty? ? nil : process(exp.shift)
    # HACK "break" + (val ? " #{val}" : "")
    if val then
      "break #{val}"
    else
      "break"
    end
  end

  def process_call(exp)
str = exp.inspect
    receiver_node_type = exp.first.nil? ? nil : exp.first.first
    receiver = process exp.shift
    receiver = "(#{receiver})" if ASSIGN_NODES.include? receiver_node_type

    name = exp.shift
    args = []
    raw = []

    # this allows us to do both old and new sexp forms:
    exp.push(*exp.pop[1..-1]) if exp.size == 1 && exp.first.first == :arglist

    @calls.push name

    in_context :arglist do
      until exp.empty? do
        arg_type = exp.first.sexp_type
        e = exp.shift
        raw << e.dup
        arg = process e

        next if arg.empty?

        strip_hash = (arg_type == :hash and
                      not BINARY.include? name and
                      (exp.empty? or exp.first.sexp_type == :splat))
        wrap_arg = Ruby2Ruby::ASSIGN_NODES.include? arg_type

        arg = arg[2..-3] if strip_hash
        arg = "(#{arg})" if wrap_arg

        args << arg
      end
    end
#str+
    case name
    when *BINARY then
      "(#{receiver} #{name} #{args.join(', ')})"
    when :[] then
      receiver ||= "self"
      if raw.size == 1 && raw.first.sexp_type == :lit && raw.first.to_a[1].kind_of?(Symbol)
        "#{receiver}.#{args.first[1..-1]}"
      else
        "#{receiver}[#{args.join(', ')}]"
      end
    when :[]= then
      receiver ||= "self"
      rhs = args.pop
      "#{receiver}[#{args.join(', ')}] = #{rhs}"
    when :"-@" then
      "-#{receiver}"
    when :"+@" then
      "+#{receiver}"
    when :new
      args     = nil                   if args.empty?
      args     = "(#{args.join(',')})" if args
      receiver = "#{receiver}"         if receiver

      "#{name} #{receiver}#{args}"
    when :lambda
      receiver = "#{receiver}."        if receiver

      "#{receiver}function"
    else
      args     = nil                 if args.empty?
      args     = "#{args.join(',')}" if args
      receiver = "#{receiver}."      if receiver

      "#{receiver}#{name}(#{args})"
    end
  ensure
    @calls.pop
  end
  
  def process_const(exp)
    exp.shift.to_s
  end

  def process_defn(exp)
    type1 = exp[1].first
    type2 = exp[2].first rescue nil

    if type1 == :args and [:ivar, :attrset].include? type2 then
      name = exp.shift
      case type2
      when :ivar then
        exp.clear
        return "attr_reader #{name.inspect}"
      when :attrset then
        exp.clear
        return "attr_writer :#{name.to_s[0..-2]}"
      else
        raise "Unknown defn type: #{exp.inspect}"
      end
    end

    case type1
    when :scope, :args then
      name = exp.shift
      args = process(exp.shift)
      args = "" if args == "()"
      body = []
      until exp.empty? do
        body << indent(process(exp.shift))
      end
      body = body.join("\n")
      return "#{exp.comments}#{name}#{args}{\n#{body}\n}".gsub(/\n\s*\n+/, "\n")
    else
      raise "Unknown defn type: #{type1} for #{exp.inspect}"
    end
  end

  def process_hash(exp)
    result = []

    until exp.empty?
      e = exp.shift
      if e.sexp_type == :lit
        lhs = process(e)
        rhs = exp.shift
        t = rhs.first
        rhs = process rhs
        rhs = "(#{rhs})" unless [:lit, :str, :array, :iter].include? t # TODO: verify better!

        result << "\n#{lhs[1..-1]}: #{rhs}"
      else
        lhs = process(e)
        rhs = exp.shift
        t = rhs.first
        rhs = process rhs
        rhs = "(#{rhs})" unless [:lit, :str].include? t # TODO: verify better!

        result << "\n#{lhs}: #{rhs}"
      end
    end

    return "{ #{indent(result.join(', '))} }"
  end

  def process_iasgn(exp)
    lhs = exp.shift
    if exp.empty? then # part of an masgn
      lhs.to_s
    else
      if lhs.to_s[0] == '@'
        "self.#{lhs.to_s[1..-1]} = #{process exp.shift}"
      else
        "#{lhs} = #{process exp.shift}"
      end
    end
  end

  def process_if(exp)
    expand = Ruby2Ruby::ASSIGN_NODES.include? exp.first.first
    c = process exp.shift
    t_type = exp.first.sexp_type
    t = process exp.shift
    f_type = exp.first.sexp_type if exp.first
    f = process exp.shift

    c = "(#{c.chomp})" #if c =~ /\n/

    if t then
      #unless expand then
      #  if f then
      #    r = "#{c} ? (#{t}) : (#{f})"
      #    r = nil if r =~ /return/ # HACK - need contextual awareness or something
      #  else
      #    r = "#{t} if #{c}"
      #  end
      #  return r if r and (@indent+r).size < LINE_LENGTH and r !~ /\n/
      #end

      r = "if#{c}{\n#{indent(t)}#{[:block, :while, :if].include?(t_type) ? '':';'}\n"
      r << "}else{\n#{indent(f)}#{[:block, :while, :if].include?(f_type) ? '':';'}\n" if f
      r << "}"

      r
    elsif f
      unless expand then
        r = "#{f} unless #{c}"
        return r if (@indent+r).size < LINE_LENGTH and r !~ /\n/
      end
      "unless #{c} then\n#{indent(f)}\nend"
    else
      # empty if statement, just do it in case of side effects from condition
      "if #{c} then\n#{indent '# do nothing'}\nend"
    end
  end

  def process_iter(exp)
    iter = process exp.shift
    args = exp.shift
    args = (args == 0) ? '' : process(args)
    body = exp.empty? ? nil : process(exp.shift)

    b, e = #if iter == "END" then
             [ "{", "}" ]
           #else
          #   [ "do", "end" ]
          # end

    iter.sub!(/\(\)$/, '')

    result = []
    result << "#{iter}(#{args})"
    result << "#{b}"
    result << "\n"
    if body then
      result << indent(body.strip)
      result << "\n"
    end
    result << e
    result.join
  end

  def process_ivar(exp)
    "this.#{exp.shift.to_s[1..-1]}"
  end

  def process_lasgn(exp)
    s = "#{exp.shift}"
    s += " = #{process exp.shift}" unless exp.empty?
    s
  end

  def process_lit(exp)
    obj = exp.shift
    case obj
    when Range then
      "(#{obj.inspect})"
    else
      obj.inspect
    end
  end

  def process_lvar(exp)
    exp.shift.to_s
  end

  def process_masgn(exp)
    lhs = exp.shift
    rhs = exp.empty? ? nil : exp.shift

    case lhs.first
    when :array then
      lhs.shift
      lhs = lhs.map do |l|
        case l.first
        when :masgn then
          "(#{process(l)})"
        else
          process(l)
        end
      end
    when :lasgn then
      lhs = [ splat(lhs.last) ]
    when :splat then
      lhs = [ :"*" ]
    else
      raise "no clue: #{lhs.inspect}"
    end

    if context[1] == :iter and rhs then
      lhs << splat(rhs[1])
      rhs = nil
    end

    unless rhs.nil? then
      t = rhs.first
      rhs = process rhs
      rhs = rhs[1..-2] if t == :array # FIX: bad? I dunno
      return "#{lhs.join(", ")} = #{rhs}"
    else
      return lhs.join(", ")
    end
  end

  def process_nil(exp)
    "null"
  end

  def process_return(exp)
    if exp.empty? then
      return "return"
    else
      return "return #{process exp.shift}"
    end
  end

  def process_scope(exp)
    exp.empty? ? "" : process(exp.shift)
  end

  def process_true(exp)
    "true"
  end

  def process_until(exp)
    cond_loop(exp, 'until')
  end

  def process_while(exp)
    cond_loop(exp, 'while')
  end
  
end

module Goling
  class Linguified
    
    def indent
      @indenture ||= ''
      @indenture += '  '
    end
    def indenture
      @indenture ||= ''
      @indenture
    end
    def indenture= str
      @indenture = str
    end
    def new_line
      "\n" + indenture
    end
    def dent
      @indenture ||= ''
      @indenture = @indenture[2..-1]
    end

    def to_js sexy = @sexy
      Ruby2Js.new.process(sexy)
    end

  end
end
