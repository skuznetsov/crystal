require "../spec_helper"

describe "Type interning" do
  it "union of returns same type object" do
    program = Program.new
    
    nil_int1 = program.union_of(program.nil, program.int32)
    nil_int2 = program.union_of(program.nil, program.int32)
    
    nil_int1.object_id.should eq(nil_int2.object_id)
  end

  it "array instantiation returns same type object" do
    program = Program.new
    
    array_int1 = program.array_of(program.int32)
    array_int2 = program.array_of(program.int32)
    
    array_int1.object_id.should eq(array_int2.object_id)
  end
end
