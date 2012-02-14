class Symbol
  unless method_defined?(:<=>)
    def <=>(other)
      case other
      when Symbol
        to_s <=> other.to_s
      else
        nil
      end
    end
  end
end
