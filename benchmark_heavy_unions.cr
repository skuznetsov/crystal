# Heavy stress test for type_merge - creates MANY unions
# This should trigger O(n²) bottleneck in old version

module HeavyUnions
  # Create 100 different types through conditionals
  def self.huge_case(x : Int32)
    case x % 100
    {% for i in 0...100 %}
    when {{i}} then {{i}}
    {% end %}
    else
      -1
    end
  end

  # Create deeply nested union merges
  def self.merge_many_paths(a, b, c, d, e)
    result = if a > 0
      if b > 0
        if c > 0
          if d > 0
            if e > 0
              1
            else
              "one"
            end
          else
            'c'
          end
        else
          true
        end
      else
        [1, 2, 3]
      end
    else
      {x: 1}
    end

    result2 = if a < 0
      if b < 0
        if c < 0
          if d < 0
            if e < 0
              2.0
            else
              :symbol
            end
          else
            nil
          end
        else
          false
        end
      else
        [4, 5]
      end
    else
      {y: 2}
    end

    {result, result2}
  end

  # Multiple functions creating unions that need to be merged
  {% for n in 1..20 %}
  def self.func_{{n}}(x : Int32)
    case x % 10
    when 0 then {{n}}
    when 1 then "{{n}}"
    when 2 then '{{('a'.ord + n).chr}}'
    when 3 then {{n}}.0
    when 4 then true
    when 5 then false
    when 6 then nil
    when 7 then [{{n}}]
    when 8 then {{{n}}}
    else
      :{{n.id}}
    end
  end
  {% end %}

  # Call all functions to force type merging
  def self.call_all(x : Int32)
    [
      {% for n in 1..20 %}
      func_{{n}}(x),
      {% end %}
    ]
  end
end

# Generate usage
puts HeavyUnions.huge_case(42)
puts HeavyUnions.merge_many_paths(1, 2, 3, 4, 5)
puts HeavyUnions.call_all(7)
