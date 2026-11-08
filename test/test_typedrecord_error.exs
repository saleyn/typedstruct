defmodule TestTypedrecordError do
  use ExUnit.Case

  test "typedrecord without name gives meaningful error" do
    assert_raise ArgumentError,
                 ~r/typedrecord requires a record name/,
                 fn ->
                   defmodule User do
                     use TypedStruct

                     typedrecord do
                       field :name, String.t()
                     end
                   end
                 end
  end
end
