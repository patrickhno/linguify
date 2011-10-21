
class Proc
  def to_reduction args={}
    Goling::Reduction.new(
      :returns  => args[:returns] || '',
      :lang     => args[:lang]    || :ruby,
      :inline   => args[:inline]  || false,
      :location => source_location[0],
      :line     => source_location[1],
      :regexp   => args[:regexp]  || //.inspect,
      :args     => args[:args]    || [],
      :sexp     => self.to_sexp
    )
  end

  def to_code collection
    reduction = to_reduction

    sexy = reduction.compile
    code = Marshal.load(Marshal.dump(sexy.first)) # sexy is not cleanly duplicated
    code.replace_variable_references!(Goling::Replacement.new(:sexp => collection.name),:collection)
    code
  end
end

