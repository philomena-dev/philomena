defmodule Mix.Tasks.ConvertToHeex do
  @moduledoc """
  Converts all slime files in the repository to HEEx.

  This file is substantially based on Slime's compiler, which can be found here:
      https://github.com/slime-lang/slime/blob/master/lib/slime/compiler.ex
  """

  use Mix.Task

  alias Slime.Parser.Nodes.{
    DoctypeNode,
    EExNode,
    EExCommentNode,
    HTMLCommentNode,
    HTMLNode,
    InlineHTMLNode,
    VerbatimTextNode
  }

  alias Slime.Doctype

  @void_elements ~w(
    area br col doctype embed hr img input link meta base param
    keygen source menuitem track wbr
  )

  @indent "  "

  def run(_) do
    Path.wildcard("lib/**/*.html.slime")
    |> Enum.sort()
    |> Enum.each(&format_file/1)

    :ok
  end

  defp format_file(filename) do
    Mix.shell().info(filename)

    formatted_content =
      filename
      |> File.read!()
      |> format_string()

    heex_filename = String.replace(filename, ".html.slime", ".html.heex")

    File.write!(heex_filename, [formatted_content])
    File.rm!(filename)
  end

  defp format_string(source) do
    tree = Slime.Parser.parse(source)
    compile(tree, "")
  end

  defp compile(tags, indent) when is_list(tags) do
    Enum.map(tags, &compile(&1, indent))
  end

  defp compile(%DoctypeNode{name: name}, indent), do: [indent, Doctype.for(name), "\n"]

  defp compile(%VerbatimTextNode{content: content}, indent) do
    [indent, String.trim(IO.iodata_to_binary(content)), "\n"]
  end

  defp compile(%HTMLNode{name: name} = tag, indent) do
    attrs = Enum.map(tag.attributes, &render_attribute/1)
    tag_head = Enum.join([name | attrs])

    body =
      cond do
        tag.closed ->
          ["<", tag_head, "/>\n"]

        name in @void_elements ->
          ["<", tag_head, " />\n"]

        true ->
          children = compile(tag.children, indent <> @indent)
          inner = if(tag.children == [], do: [], else: ["\n", children, indent])

          [
            "<",
            tag_head,
            ">",
            inner,
            "</",
            name,
            ">\n"
          ]
      end

    [indent, body]
  end

  defp compile(%EExNode{content: code, output: output, safe?: safe?} = eex, indent) do
    if safe? do
      raise "== operator used to include safe content in template; mark as raw in view instead"
    end

    tag_indent =
      if(String.trim(code) == "else", do: unindent(indent), else: indent)

    code = reformat_code(code, eex.children)

    opening = [
      if(output, do: "<%= ", else: "<% "),
      convert_multiline(code, tag_indent <> @indent),
      "%>\n"
    ]

    closing =
      if Regex.match?(~r/(fn.*->| do)\s*$/, code) do
        [indent, "<% end %>\n"]
      else
        ""
      end

    [tag_indent, opening, compile(eex.children, tag_indent <> @indent), closing]
  end

  defp compile(%InlineHTMLNode{}, _indent) do
    raise "Inline HTML not supported"
  end

  defp compile(%HTMLCommentNode{content: content}, indent) do
    [indent, "<!-- ", raw(content), " -->\n"]
  end

  defp compile(%EExCommentNode{content: content}, indent) do
    content
    |> raw()
    |> IO.iodata_to_binary()
    |> String.split("\n")
    |> Enum.map(&[indent, "<% # ", &1, " %>\n"])
  end

  defp compile({:eex, eex}, indent), do: [indent, "<%= ", eex, " %>"]
  defp compile({:safe_eex, _eex}, _indent), do: raise("Safe EEx not supported")
  defp compile(raw, indent), do: [indent, raw]

  defp render_attribute({name, {safe_eex, content}}) do
    if safe_eex != :eex do
      raise "Unsupported attribute type '#{safe_eex}'"
    end

    case content do
      "true" ->
        " #{name}"

      "false" ->
        ""

      "nil" ->
        ""

      _ ->
        quoted_content = Code.string_to_quoted!(content)
        render_attribute_code(name, content, quoted_content)
    end
  end

  defp render_attribute({name, value}) do
    if value == true do
      " #{name}"
    else
      value =
        cond do
          is_binary(value) -> value
          is_list(value) -> Enum.join(value, " ")
          true -> value
        end

      ~s( #{name}="#{value}")
    end
  end

  defp render_attribute_code(name, _content, quoted)
       when is_number(quoted) or is_atom(quoted) do
    ~s[ #{name}="#{quoted}"]
  end

  defp render_attribute_code(name, _content, quoted) when is_list(quoted) do
    quoted |> Enum.map_join(" ", &Kernel.to_string/1) |> (&~s[ #{name}="#{&1}"]).()
  end

  defp render_attribute_code(name, _content, quoted) when is_binary(quoted),
    do: ~s[ #{name}="#{quoted}"]

  # String with interpolation
  defp render_attribute_code(
         name,
         _content,
         {:<<>>, _, [{:"::", _, [{{:., _, [Kernel, :to_string]}, _, [line]}, _]}]}
       ) do
    ~s[ #{name}={#{Macro.to_string(line)}}]
  end

  defp render_attribute_code(name, content, _) do
    ~s[ #{name}={#{content}}]
  end

  defp raw(value) when is_list(value) do
    Enum.map(value, &raw/1)
  end

  defp raw({:eex, value}), do: "\#{" <> value <> "}"
  defp raw(value), do: value

  defp convert_multiline(code, indent) do
    case String.split(code, "\n") do
      [_line] ->
        [code, " "]

      lines ->
        lines =
          Enum.map(lines, fn line ->
            if String.trim(line) == "" do
              ["\n"]
            else
              [indent, line, "\n"]
            end
          end)

        ["\n", lines, unindent(indent)]
    end
  end

  defp unindent(indent), do: String.slice(indent, 0..-3//1)

  defp reformat_code(code, []) do
    case Code.string_to_quoted(code) do
      {:ok, ast} ->
        ast
        |> Code.quoted_to_algebra()
        |> Inspect.Algebra.format(300)
        |> IO.iodata_to_binary()

      _ ->
        # Stab or do block
        code
    end
  end

  defp reformat_code(code, _), do: code
end
