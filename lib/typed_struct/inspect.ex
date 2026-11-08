# Generic Inspect implementation for typed records
# Uses persistent_term to look up field metadata registered during record compilation
# Disable via config: config :typed_struct, :inspect_records, false

# Disable warning about redefining the built-in Inspect.Tuple protocol
Code.compiler_options(ignore_module_conflict: true)

if Application.compile_env(:typed_struct, :inspect_records, true) do
  defimpl Inspect, for: Tuple do
    def inspect(tuple, opts) do
      case elem(tuple, 0) do
        tag when is_atom(tag) and tuple_size(tuple) > 1 ->
          metadata = :persistent_term.get({:typed_record_fields, tag}, nil)
          if metadata && tuple_size(tuple) == metadata.count + 1 do
            format_record(tuple, tag, metadata, opts)
          else
            format_regular_tuple(tuple, opts)
          end

        _ ->
          format_regular_tuple(tuple, opts)
      end
    end

    defp format_record(tuple, tag, metadata, opts) do
      %{fields: field_names, module: module} = metadata
      [_tag | values] = Tuple.to_list(tuple)
      fields = Enum.zip(field_names, values)
      inner_docs = Enum.map(fields, &format_field(&1, opts))

      Inspect.Algebra.container_doc(
        "#{module}.#{tag}(",
        inner_docs,
        ")",
        opts,
        fn doc, _ -> doc end,
        separator: ","
      )
    end

    defp format_field({k, v}, opts) do
      key_doc = Atom.to_string(k)
      val_doc = Inspect.Algebra.to_doc(v, opts)
      Inspect.Algebra.concat([key_doc, ": ", val_doc])
    end

    defp format_regular_tuple(tuple, _opts) do
      # Format tuple manually: {elem1, elem2, ...}
      elements = Tuple.to_list(tuple) |> Enum.map(&inspect/1)
      Inspect.Algebra.concat([
        "{",
        Enum.join(elements, ", "),
        "}"
      ])
    end
  end
end
