class Person
  def initialize(@name : String, @age : Int32)
  end

  def greet
    puts "Hello, I'm #{@name} and I'm #{@age} years old"
  end
end

def main
  person = Person.new("Alice", 30)
  person.greet

  x = 10
  y = 20
  sum = x + y
  puts sum
end

main
