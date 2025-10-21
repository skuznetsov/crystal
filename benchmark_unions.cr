# Benchmark to stress-test type_merge optimization
# This code creates many unions to trigger the O(n²) bottleneck

module BenchmarkUnions
  # Create a function that merges many types through conditionals
  def self.many_branches(x : Int32)
    result = case x % 50
    when 0 then 0
    when 1 then "a"
    when 2 then 'b'
    when 3 then true
    when 4 then false
    when 5 then nil
    when 6 then 1_i64
    when 7 then 2_u32
    when 8 then 3.0
    when 9 then 4.5_f32
    when 10 then [1, 2, 3]
    when 11 then {1, 2}
    when 12 then {a: 1, b: 2}
    when 13 then (1..10)
    when 14 then /regex/
    when 15 then :symbol
    when 16 then Set{1, 2, 3}
    when 17 then Hash{"a" => 1}
    when 18 then Time.utc(2024, 1, 1)
    when 19 then 100_i8
    when 20 then 200_u8
    when 21 then 300_i16
    when 22 then 400_u16
    when 23 then 500_i64
    when 24 then 600_u64
    when 25 then 7.0_f64
    when 26 then "string"
    when 27 then 'c'
    when 28 then true
    when 29 then false
    when 30 then [4, 5, 6]
    when 31 then {7, 8}
    when 32 then {x: 9, y: 10}
    when 33 then (20..30)
    when 34 then /another/
    when 35 then :other
    when 36 then Set{4, 5}
    when 37 then Hash{"b" => 2}
    when 38 then 1000
    when 39 then "test"
    when 40 then 'd'
    when 41 then nil
    when 42 then 42
    when 43 then "43"
    when 44 then 'e'
    when 45 then 45.0
    when 46 then true
    when 47 then [7, 8, 9]
    when 48 then {10, 11}
    else
      99
    end

    result
  end

  # Another function with complex nested conditionals
  def self.nested_unions(a : Int32, b : Int32)
    if a > 0
      if b > 0
        1
      elsif b < -10
        "negative"
      else
        'c'
      end
    elsif a < -5
      if b > 100
        true
      else
        [1, 2, 3]
      end
    else
      if b.even?
        {a: a, b: b}
      else
        nil
      end
    end
  end

  # Function that creates unions from arrays
  def self.array_unions
    arr = [1, "two", 'c', true, nil, 5.5, :symbol, [1, 2], {x: 1}]
    arr.first?
  end

  # Generic function creating unions
  def self.generic_unions(x : T) forall T
    if x.responds_to?(:to_i)
      x.to_i
    elsif x.responds_to?(:to_s)
      x.to_s
    else
      nil
    end
  end
end

# Use the functions to ensure they're compiled
puts BenchmarkUnions.many_branches(42)
puts BenchmarkUnions.nested_unions(10, 20)
puts BenchmarkUnions.array_unions
puts BenchmarkUnions.generic_unions(123)
puts BenchmarkUnions.generic_unions("test")
