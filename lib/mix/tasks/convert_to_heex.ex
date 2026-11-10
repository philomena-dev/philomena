defmodule Mix.Tasks.ConvertToHeex do
  @moduledoc """
  Converts all slime files in the repository to HEEx.

  Slime renders no whitespace between nodes unless asked to. The HEEx output
  reproduces that: it only puts a line break between two nodes when at least
  one side already renders whitespace or is laid out as a block, where the
  break cannot be visible.

  `Phoenix.LiveView.HTMLFormatter` inserts line breaks of its own around
  EEx blocks and block-level tags. Wherever such a break would be visible,
  the converter either moves a lone `if`/`unless`/`for` into a `:if`/`:for`
  attribute of the element it wraps, or marks the enclosing element with
  `phx-no-format`. Elements whose whitespace is significant are marked
  with `phx-no-format` as well.

  This file is substantially based on Slime's compiler, which can be found here:
      https://github.com/slime-lang/slime/blob/master/lib/slime/compiler.ex
  """

  use Mix.Task

  alias Slime.Parser.Nodes.{
    DoctypeNode,
    EExNode,
    HTMLCommentNode,
    HTMLNode,
    InlineHTMLNode,
    VerbatimTextNode
  }

  alias Slime.Doctype

  @templates "lib/philomena_web/templates"

  @void_elements ~w(
    area br col doctype embed hr img input link meta base param
    keygen source menuitem track wbr
  )

  # Tags that Phoenix.LiveView.HTMLFormatter treats as inline
  @inline_tags ~w(a abbr acronym audio b bdi bdo big br button canvas cite
  code data datalist del dfn em embed i iframe img input ins kbd label map
  mark meter noscript object output picture progress q ruby s samp select slot
  small span strong sub sup svg template textarea time u tt var video wbr)

  # Classes that assets/css lays out as inline-block, inline-flex or inline-grid
  @inline_block_classes ~w(
    autocomplete badge badges button checkbox-label-of-doom commission__category
    dropdown fancy-checkbox fancy-toggle favicon-home header__counter
    header__counter__admin header__link image-show-container input--decoy
    interaction-user-list-item label--block profile-block
    quick-tag-table__tab-separator scraper-preview--image-wrapper spoiler
    spoiler-revealed tag tag__dropdown-icon
  )

  # Classes that assets/css lays out inline
  @inline_classes ~w(button_to)

  # Tags laid out as inline-block (nav by assets/css, the rest by browsers)
  @inline_block_tags ~w(button iframe img input nav select textarea video)

  # Ancestor classes whose descendants of the given tags assets/css lays
  # out as inline-block
  @inline_block_descendants %{
    "block__header" => ~w(a),
    "block__header--sub" => ~w(a),
    "horizontal-list" => ~w(li),
    "image-container" => ~w(a picture video)
  }

  # Parent classes whose children of the given tags assets/css lays out as
  # inline-block
  @inline_block_children %{
    "media-box__header--link-row" => ~w(a),
    "quick-tag-table__tab" => ~w(div)
  }

  # Classes and ids that assets/css lays out as flex or grid containers,
  # which never render whitespace between their children
  @flex_classes ~w(
    approval-grid approval-items--footer approval-items--main approval-items__details
    autocomplete__item__history autocomplete__item__history__delete autocomplete__item__tag
    block__header--js-tabbed block__header__buttons center--layout--flex checkbox-button
    choice-text column-layout comparison--navigation difference
    dupe-report-list--image-container field--inline flex grid header__counter
    header__counter__admin header__link-user header__navigation image-constrained
    image-container image_sources media--featured media-grid media-list minimal onion-skin
    onion-skin__slider-box page__header permission-choices poll-form__options__label
    poll-option__counts poll-option__text poll-results poll-vote-form profile-top
    profile-top__options rule__badges rule__footer rule__header sparkline
    staff-block__grid staff-block__user-card swipe table-list__label tag tag-list
    tag__change tag__change-block tag__change-image tag__change-info tag__change-revert
    tag__change-tools tag__changes tag__dropdown-icon tag_change-tag-count tagsinput
  )
  @flex_ids ~w(container footer footer_content imagespns__link js-image-upload-previews)

  # Ancestor class whose list items assets/css lays out inline
  @inline_items_class "filter-options"

  # Ancestor classes that decide how assets/css lays out a partial
  @context_classes [@inline_items_class | Map.keys(@inline_block_descendants)]
  @any_context "*"
  @code_contexts [[], [@any_context]]

  # Partials rendered as the children of .quick-tag-table__tab
  @quick_tag_table_partial ~r{/tag/_quick_tag_table_\w+\.html\.slime$}

  # Classes that assets/css styles with `white-space: pre*`
  @preserve_classes ~w(diff__text literal poll-option__label spoiler-filter-code)

  # Tags whose text is used verbatim (title is shown by the browser and
  # matched by tests)
  @preserve_tags ~w(pre textarea title)

  # Tags that Phoenix.LiveView.HTMLFormatter already keeps verbatim
  @formatter_preserve_tags ~w(pre textarea)

  @comment_marker "__heex_comment__"

  def run(_) do
    files = Path.wildcard("lib/**/*.html.slime") |> Enum.sort()

    parsed = Map.new(files, &{&1, parse_file(&1)})
    Process.put(:templates, parsed)
    Process.put(:render_contexts, render_contexts(files, %{}))

    Process.put(
      :templates,
      Map.new(parsed, fn {file, nodes} -> {file, hoist_edge_spaces(nodes, root_ctx(file))} end)
    )

    Process.put(:unprotected, [])
    Process.put(:root_edges, root_edges(files, %{}))

    Enum.each(files, &format_file/1)

    for {file, kind} <- Enum.reverse(Process.get(:unprotected)) do
      Mix.shell().error("#{file}: formatter break at the template root: #{inspect(kind)}")
    end
  end

  ## Parsing

  defp parse_file(filename) do
    source = File.read!(filename)
    preprocessed = preserve_comments(source)

    expected = Slime.Renderer.precompile(source)

    actual =
      preprocessed
      |> Slime.Renderer.precompile()
      |> then(
        &Regex.replace(~r/<% #{@comment_marker}\((\d+), "[^"]*"\) %>/, &1, fn _, n ->
          String.duplicate(" ", String.to_integer(n))
        end)
      )

    if expected != actual do
      raise "#{filename}: comment preprocessing changed the rendered output"
    end

    preprocessed
    |> Slime.Parser.parse()
    |> lift_children()
    |> tag_nodes()
  end

  # Slime's parser discards the text of `/` comments, but renders their
  # indentation. Turn them into code nodes so both survive parsing.
  defp preserve_comments(source) do
    source
    |> String.split("\n")
    |> collect_comments([])
    |> Enum.join("\n")
  end

  defp collect_comments([], acc), do: Enum.reverse(acc)

  defp collect_comments([line | rest], acc) do
    case Regex.run(~r{^([ \t]*)/(?!!)(.*)$}, line) do
      [_, indent, text] ->
        # Deeper indented lines continue the comment
        {nested, rest} =
          Enum.split_while(rest, &(String.trim(&1) == "" or indent_of(&1) > byte_size(indent)))

        {blank, nested} = nested |> Enum.reverse() |> Enum.split_while(&(String.trim(&1) == ""))
        text = Enum.join([text | Enum.reverse(nested)], "\n")

        marker =
          "#{indent}- #{@comment_marker}(#{byte_size(indent)}, #{inspect(Base.encode64(text))})"

        collect_comments(blank ++ rest, [marker | acc])

      nil ->
        collect_comments(rest, [line | acc])
    end
  end

  defp indent_of(line), do: byte_size(line) - byte_size(String.trim_leading(line))

  # Slime renders the children of a code line that opens no block right
  # after it, so they are really its siblings.
  defp lift_children(nodes) when is_list(nodes) do
    Enum.flat_map(nodes, fn
      %EExNode{} = eex ->
        children = lift_children(eex.children)

        if opens_block?(eex) or clause?(eex),
          do: [%{eex | children: children}],
          else: [%{eex | children: []} | children]

      %HTMLNode{} = tag ->
        [%{tag | children: lift_children(tag.children)}]

      node ->
        [node]
    end)
  end

  # The formatter drops whitespace-only text at the edges of inline tags,
  # and adds a space before trailing text that both starts and ends with
  # one. Move edge whitespace out of inline tags, or drop it where an
  # inline-block layout hides it anyway.
  defp hoist_edge_spaces(nodes, ctx) do
    Enum.map(nodes, fn
      %HTMLNode{} = tag ->
        if preserve?(tag), do: tag, else: hoist_tag_spaces(tag, ctx)

      %EExNode{} = eex ->
        %{eex | children: hoist_edge_spaces(eex.children, ctx)}

      node ->
        node
    end)
  end

  defp hoist_tag_spaces(%HTMLNode{name: name} = tag, ctx) do
    classes = static_classes(tag)

    child_ctx = %{
      ctx
      | parent_classes: classes,
        ancestor_classes: ctx.ancestor_classes ++ classes,
        in_inline_items: ctx.in_inline_items or @inline_items_class in classes
    }

    children = hoist_edge_spaces(tag.children, child_ctx)

    {stripped, leading} = strip_edge_space(children, :leading)
    {stripped, trailing} = stripped |> Enum.reverse() |> strip_edge_space(:trailing)
    stripped = Enum.reverse(stripped)

    cond do
      name not in @inline_tags or not (leading or trailing) ->
        %{tag | children: children}

      display(tag, ctx) == :inline ->
        spaces =
          tag.spaces
          |> Map.merge(if leading, do: %{leading: true}, else: %{})
          |> Map.merge(if trailing, do: %{trailing: true}, else: %{})

        %{tag | children: stripped, spaces: spaces}

      # Where the call sites disagree on the layout, the whitespace stays
      # and the formatter stays out
      display(tag, ctx) == :ambiguous ->
        %{tag | children: children, attributes: tag.attributes ++ [{"phx-no-format", true}]}

      true ->
        %{tag | children: stripped}
    end
  end

  # Strips whitespace off the first rendered node of `nodes`, which is in
  # reverse order for the trailing edge
  defp strip_edge_space([], _edge), do: {[], false}

  defp strip_edge_space([node | rest], edge) do
    case strip_node_space(node, edge) do
      {:stripped, nil} ->
        {rest, _} = strip_edge_space(rest, edge)
        {rest, true}

      {:stripped, node} ->
        {[node | rest], true}

      :transparent ->
        {rest, stripped} = strip_edge_space(rest, edge)
        {[node | rest], stripped}

      :kept ->
        {[node | rest], false}
    end
  end

  defp strip_node_space(%VerbatimTextNode{content: content} = text, edge) do
    items = if edge == :leading, do: content, else: Enum.reverse(content)
    {blank, items} = Enum.split_while(items, &(&1 == ""))
    trim = if edge == :leading, do: &String.trim_leading/1, else: &String.trim_trailing/1

    case items do
      [] ->
        :transparent

      [item | rest] when is_binary(item) ->
        if trim.(item) == item do
          :kept
        else
          items = blank ++ [trim.(item) | rest]
          content = if edge == :leading, do: items, else: Enum.reverse(items)

          if Enum.all?(content, &(&1 == "")),
            do: {:stripped, nil},
            else: {:stripped, %{text | content: content}}
        end

      _ ->
        :kept
    end
  end

  defp strip_node_space(%HTMLNode{spaces: spaces} = tag, edge) do
    if spaces[edge], do: {:stripped, %{tag | spaces: Map.delete(spaces, edge)}}, else: :kept
  end

  defp strip_node_space(%EExNode{} = eex, edge) do
    cond do
      comment?(eex) and comment_indent(eex) > 0 ->
        {:stripped,
         %{
           eex
           | content: Regex.replace(~r/^(\s*#{@comment_marker}\()\d+/, eex.content, "\\g{1}0")
         }}

      comment?(eex) or not eex.output ->
        :transparent

      eex.spaces[edge] ->
        {:stripped, %{eex | spaces: Map.delete(eex.spaces, edge)}}

      true ->
        :kept
    end
  end

  defp strip_node_space(_node, _edge), do: :kept

  # Gives every element and code node an identity, so the analysis can
  # point at them
  defp tag_nodes(nodes) when is_list(nodes) do
    Enum.map(nodes, fn
      %EExNode{} = eex -> Map.put(%{eex | children: tag_nodes(eex.children)}, :uid, make_ref())
      %HTMLNode{} = tag -> Map.put(%{tag | children: tag_nodes(tag.children)}, :uid, make_ref())
      node -> node
    end)
  end

  defp uid(node), do: :maps.get(:uid, node, nil)

  ## Conversion

  defp format_file(filename) do
    Mix.shell().info(filename)

    nodes =
      Process.get(:templates)
      |> Map.fetch!(filename)
      |> move_into_special_attributes(filename)

    events = analyze(nodes, filename)

    for {kind, :root, _} <- events do
      Process.put(:unprotected, [{filename, kind} | Process.get(:unprotected)])
    end

    no_format = for {_, uid, _} <- events, uid != :root, into: MapSet.new(), do: uid

    ctx = %{root_ctx(filename) | no_format_marks: no_format}
    {left, right} = root_edge(filename)
    formatted_content = compile_children(nodes, ctx, left, right, "", "")

    heex_filename = String.replace(filename, ".html.slime", ".html.heex")

    # Slime strips trailing spaces from lines, so any here precede a break
    content = Regex.replace(~r/[ \t]+$/m, IO.iodata_to_binary(formatted_content), "")
    File.write!(heex_filename, [String.trim(content), "\n"])
    File.rm!(filename)
  end

  # Ancestor classes each template may be rendered under, as far as they
  # decide the layout: a list of class lists, taken from the templates that
  # render it. Code rendering a partial may put it anywhere, which the
  # `@any_context` class stands for.
  defp render_contexts(files, contexts) do
    Process.put(:render_contexts, contexts)

    new_contexts =
      for(
        file <- files,
        {path, ancestors} <- render_sites(Map.fetch!(Process.get(:templates), file), file, []),
        outer <- root_contexts(file),
        do: {path, Enum.sort(Enum.uniq(outer ++ ancestors))}
      )
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Map.new(fn {path, list} ->
        {path, Enum.uniq(if rendered_by_code?(path), do: @code_contexts ++ list, else: list)}
      end)

    if new_contexts == contexts, do: contexts, else: render_contexts(files, new_contexts)
  end

  defp root_contexts(file) do
    default = if rendered_by_code?(file), do: @code_contexts, else: [[]]
    Map.get(Process.get(:render_contexts, %{}), file, default)
  end

  defp render_sites(nodes, file, ancestors) do
    Enum.flat_map(nodes, fn
      %HTMLNode{} = tag ->
        classes = Enum.filter(static_classes(tag), &(&1 in @context_classes))
        render_sites(tag.children, file, ancestors ++ classes)

      %EExNode{} = eex ->
        sites =
          case render_path(eex.content, %{file: file}) do
            {:ok, path} when eex.output -> [{path, ancestors}]
            _ -> []
          end

        sites ++ render_sites(eex.children, file, ancestors)

      _ ->
        []
    end)
  end

  # Kinds facing the edges of each template, taken from the templates that
  # render it. A page sits in the block layout; a partial that Elixir code
  # renders may end up in inline context.
  defp root_edges(files, edges) do
    Process.put(:root_edges, edges)
    Process.put(:render_calls, [])

    for file <- files do
      {left, right} = root_edge(file)
      ctx = %{root_ctx(file) | collect_renders: true}
      compile_children(Map.fetch!(Process.get(:templates), file), ctx, left, right, "", "")
    end

    new_edges =
      Process.get(:render_calls)
      |> Enum.group_by(&elem(&1, 0), &Tuple.delete_at(&1, 0))
      |> Map.new(fn {path, calls} ->
        calls = if rendered_by_code?(path), do: [{:unsafe, :unsafe, false} | calls], else: calls

        {path,
         {all_safe(Enum.map(calls, &elem(&1, 0))), all_safe(Enum.map(calls, &elem(&1, 1))),
          Enum.all?(calls, &elem(&1, 2))}}
      end)

    if new_edges == edges, do: edges, else: root_edges(files, new_edges)
  end

  defp root_edge(file) do
    {left, right, _flex} = root_context(file)
    {left, right}
  end

  defp root_context(file),
    do: Map.get(Process.get(:root_edges, %{}), file, default_root_context(file))

  defp default_root_context(file) do
    if partial?(file), do: {:unsafe, :unsafe, false}, else: {:safe, :safe, false}
  end

  defp partial?(file), do: String.starts_with?(Path.basename(file), "_")

  defp rendered_by_code?(file) do
    name = inspect(Path.basename(file, ".slime"))

    partial?(file) and
      "lib/**/*.ex"
      |> Path.wildcard()
      |> Enum.any?(&(&1 |> File.read!() |> String.contains?(name)))
  end

  defp record_render(eex, ctx, before, after_) do
    with true <- ctx.collect_renders,
         {:ok, path} <- render_path(eex.content, ctx) do
      # Whitespace next to a flex item never renders
      left = if ctx.flex or eex.spaces[:leading], do: :safe, else: before
      right = if ctx.flex or eex.spaces[:trailing], do: :safe, else: after_
      call = {path, left, right, ctx.flex and eex.spaces == %{}}
      Process.put(:render_calls, [call | Process.get(:render_calls)])
    end
  end

  defp root_ctx(filename) do
    %{
      file: filename,
      preserve: false,
      no_format: false,
      no_format_marks: MapSet.new(),
      analyze: false,
      collect_renders: false,
      enclosing: :root,
      parent_classes:
        if(Regex.match?(@quick_tag_table_partial, filename),
          do: ["quick-tag-table__tab"],
          else: []
        ),
      ancestor_classes: [],
      root_contexts: root_contexts(filename),
      in_inline_items: false,
      in_hform: false,
      inline_parent: false,
      flex: elem(root_context(filename), 2)
    }
  end

  # Returns where the formatter would insert a visible line break, as
  # `{kind, enclosing, block}`: the uid of the nearest enclosing element (or
  # `:root`), and the uid of the code block whose body gets the break.
  defp analyze(nodes, filename) do
    Process.put(:damage, [])
    {left, right} = root_edge(filename)
    compile_children(nodes, %{root_ctx(filename) | analyze: true}, left, right, "", "")
    Process.get(:damage)
  end

  defp damage(ctx, kind, block \\ nil) do
    if ctx.analyze and not ctx.no_format do
      Process.put(:damage, [{kind, ctx.enclosing, block} | Process.get(:damage)])
    end
  end

  # A lone element in an `if`/`unless` or `for` can carry the condition or
  # the generator itself, which keeps the formatter away from it. With an
  # `else` holding a lone element too, each element gets its own condition.
  defp move_into_special_attributes(nodes, filename) do
    blocks = for {{:body, _}, _, uid} <- analyze(nodes, filename), into: MapSet.new(), do: uid

    case move_specials(nodes, blocks) do
      {nodes, true} -> move_into_special_attributes(nodes, filename)
      {nodes, false} -> nodes
    end
  end

  defp move_specials(nodes, blocks) do
    {nodes, changed} =
      Enum.map_reduce(nodes, false, fn node, changed ->
        case node do
          %EExNode{children: children} = eex ->
            with true <- MapSet.member?(blocks, uid(eex)),
                 {:ok, tags, spaces} <- special_elements(eex) do
              {with_outer_spaces(tags, Map.merge(spaces, eex.spaces)), true}
            else
              _ ->
                {children, child_changed} = move_specials(children, blocks)
                {[%{eex | children: children}], changed or child_changed}
            end

          %HTMLNode{children: children} = tag ->
            {children, child_changed} = move_specials(children, blocks)
            {[%{tag | children: children}], changed or child_changed}

          node ->
            {[node], changed}
        end
      end)

    {Enum.concat(nodes), changed}
  end

  defp with_outer_spaces([first | rest], spaces) do
    tags = [%{first | spaces: Map.take(spaces, [:leading])} | rest]
    List.update_at(tags, -1, &%{&1 | spaces: Map.merge(&1.spaces, Map.take(spaces, [:trailing]))})
  end

  defp special_elements(%EExNode{content: code} = eex) do
    code = String.trim(code)

    attrs =
      case {Regex.run(~r/^(if|unless|for)\s+(.*)\s+do$/s, code), clause_bodies(eex)} do
        {[_, "if", condition], [{nil, _}]} ->
          [":if": condition]

        {[_, "unless", condition], [{nil, _}]} ->
          [":if": "!(#{condition})"]

        {[_, "for", generator], [{nil, _}]} ->
          [":for": generator]

        {[_, "if", condition], [{nil, _}, {"else", _}]} ->
          [":if": condition, ":if": "!(#{condition})"]

        {[_, "unless", condition], [{nil, _}, {"else", _}]} ->
          [":if": "!(#{condition})", ":if": condition]

        _ ->
          []
      end

    bodies = Enum.map(clause_bodies(eex), &elem(&1, 1))
    spaces = Enum.map(bodies, &lone_element_spaces/1)

    # Spaces around the elements render whatever the condition, so every
    # branch must have the same, and an empty branch none
    if attrs != [] and :error not in spaces and length(Enum.uniq(spaces)) == 1 and
         (length(attrs) > 1 or hd(spaces) == %{}) do
      {:ok,
       Enum.zip_with(attrs, bodies, fn {name, value}, [tag] ->
         attributes = [{:special, Atom.to_string(name), value} | tag.attributes]
         %{tag | attributes: attributes, spaces: %{}}
       end), hd(spaces)}
    else
      :error
    end
  end

  defp lone_element_spaces([%HTMLNode{spaces: spaces} = tag]),
    do: if(special?(tag), do: :error, else: spaces)

  defp lone_element_spaces(_body), do: :error

  defp special?(%HTMLNode{attributes: attrs}), do: Enum.any?(attrs, &match?({:special, _, _}, &1))

  ## Whitespace analysis
  #
  # Every node has a leading kind, a trailing kind, and whether it may
  # render nothing:
  #
  #   * :safe - whitespace next to this edge is invisible (block element, or
  #     the node already renders whitespace there)
  #   * :unsafe - whitespace next to this edge may be visible
  #   * :never, :maybe or :always - the node renders nothing
  #
  # A line break may separate two nodes when either facing edge is :safe.
  # The edge facing a gap is found by looking through the nodes that may
  # render nothing.

  @nothing {:unsafe, :unsafe, :always}

  defp kinds(%DoctypeNode{}, _ctx), do: {:safe, :safe, :never}

  # Whitespace around a line break sits at the end or start of a line
  defp kinds(%HTMLNode{name: "br", spaces: spaces}, _ctx),
    do: with_spaces(spaces, {:safe, :safe, :never})

  defp kinds(%HTMLNode{} = tag, ctx) do
    base = if display(tag, ctx) == :block, do: :safe, else: :unsafe
    with_spaces(tag.spaces, {base, base, if(special?(tag), do: :maybe, else: :never)})
  end

  defp kinds(%EExNode{} = eex, ctx) do
    cond do
      comment?(eex) ->
        if comment_indent(eex) > 0, do: {:safe, :safe, :never}, else: @nothing

      not eex.output ->
        @nothing

      not opens_block?(eex) ->
        with_spaces(eex.spaces, render_kinds(eex.content, ctx))

      true ->
        with_spaces(eex.spaces, block_kinds(eex, ctx))
    end
  end

  defp kinds(%VerbatimTextNode{content: content}, _ctx) do
    case Enum.reject(content, &(&1 == "")) do
      [] ->
        @nothing

      items ->
        {text_kind(hd(items), &String.first/1), text_kind(List.last(items), &String.last/1),
         :never}
    end
  end

  defp with_spaces(spaces, kinds) when spaces == %{}, do: kinds

  defp with_spaces(spaces, {lead, trail, empty}) do
    {if(spaces[:leading] == true or empty == :always, do: :safe, else: lead),
     if(spaces[:trailing] == true or empty == :always, do: :safe, else: trail), :never}
  end

  defp text_kind(text, edge) when is_binary(text) do
    if String.trim(edge.(text)) == "", do: :safe, else: :unsafe
  end

  defp text_kind(_eex, _edge), do: :unsafe

  defp block_kinds(eex, ctx) do
    case wrapper(eex.content) do
      :control ->
        branches = Enum.map(branches(eex), &list_kinds(&1, ctx))
        rendering = Enum.reject(branches, &(elem(&1, 2) == :always))

        empty =
          cond do
            rendering == [] -> :always
            Enum.all?(branches, &(elem(&1, 2) == :never)) -> :never
            true -> :maybe
          end

        {all_safe(Enum.map(rendering, &elem(&1, 0))), all_safe(Enum.map(rendering, &elem(&1, 1))),
         empty}

      :loop ->
        {lead, trail, empty} = list_kinds(eex.children, ctx)
        {lead, trail, if(empty == :always, do: :always, else: :maybe)}

      wrapper when wrapper in [:form, :block] ->
        {:safe, :safe, :never}

      :inline ->
        {:unsafe, :unsafe, :never}
    end
  end

  defp all_safe(kinds), do: if(Enum.all?(kinds, &(&1 == :safe)), do: :safe, else: :unsafe)

  # Kinds of a list of nodes rendered one after another
  defp list_kinds(nodes, ctx) do
    kinds = Enum.map(nodes, &kinds(&1, ctx))

    empty =
      cond do
        Enum.all?(kinds, &(elem(&1, 2) == :always)) -> :always
        Enum.any?(kinds, &(elem(&1, 2) == :never)) -> :never
        true -> :maybe
      end

    {facing(Enum.reverse(kinds), 0, nil) || :unsafe, facing(kinds, 1, nil) || :unsafe, empty}
  end

  # The kind seen past a run of nodes, ordered from the farthest to the
  # nearest, falling back to whatever lies beyond them
  defp facing(kinds, position, fallback) do
    Enum.reduce(kinds, fallback, fn kind, acc ->
      face(elem(kind, position), elem(kind, 2), acc)
    end)
  end

  defp face(_kind, :always, acc), do: acc
  defp face(kind, :never, _acc), do: kind
  defp face(kind, :maybe, nil), do: kind
  defp face(kind, :maybe, acc), do: all_safe([kind, acc])

  defp first_kind(nodes, ctx, fallback),
    do: nodes |> Enum.map(&kinds(&1, ctx)) |> Enum.reverse() |> facing(0, fallback)

  defp last_kind(nodes, ctx, fallback),
    do: nodes |> Enum.map(&kinds(&1, ctx)) |> facing(1, fallback)

  # Kinds of a `render` call, taken from the rendered partial
  defp render_kinds(code, ctx) do
    case render_path(code, ctx) do
      {:ok, path} -> list_kinds(Map.fetch!(Process.get(:templates), path), root_ctx(path))
      :error -> {:unsafe, :unsafe, :never}
    end
  end

  defp render_path(code, ctx) do
    case Map.fetch(render_variables(ctx.file), String.trim(code)) do
      {:ok, path} -> {:ok, path}
      :error -> render_call_path(code, ctx)
    end
  end

  # Variables that templates assign a rendered partial to, like `pagination`
  defp render_variables(file) do
    key = {:render_variables, file}

    with nil <- Process.get(key) do
      variables =
        for eex <- code_nodes(Map.fetch!(Process.get(:templates), file)),
            not eex.output,
            [_, variable, call] <- Regex.scan(~r/^\s*(\w+)\s*=\s*(render\b.*)$/m, eex.content),
            {:ok, path} <- [render_call_path(call, %{file: file})],
            into: %{},
            do: {variable, path}

      Process.put(key, variables)
      variables
    end
  end

  defp code_nodes(nodes) do
    Enum.flat_map(nodes, fn
      %EExNode{} = eex -> [eex | code_nodes(eex.children)]
      %HTMLNode{children: children} -> code_nodes(children)
      _ -> []
    end)
  end

  defp render_call_path(code, ctx) do
    with [_, module, name] <-
           Regex.run(
             ~r/^render\(?\s*(?:(PhilomenaWeb\.[\w.]+View)\s*,\s*)?"([^"]+)"/,
             String.trim(code)
           ),
         path = partial_path(module, name, ctx),
         true <- Map.has_key?(Process.get(:templates), path) do
      {:ok, path}
    else
      _ -> :error
    end
  end

  defp partial_path("", name, ctx), do: Path.join(Path.dirname(ctx.file), name <> ".slime")

  defp partial_path(module, name, _ctx) do
    dir =
      module
      |> String.replace_prefix("PhilomenaWeb.", "")
      |> String.replace_suffix("View", "")
      |> String.split(".")
      |> Enum.map_join("/", &Macro.underscore/1)

    Path.join([@templates, dir, name <> ".slime"])
  end

  defp break?(_left, _right, %{preserve: true}), do: false
  defp break?(_left, _right, %{flex: true}), do: true
  defp break?(left, right, _ctx), do: left == :safe or right == :safe

  # How assets/css lays the element out: :block, :inline_block or :inline,
  # or :ambiguous when that depends on where the template is rendered
  defp display(tag, ctx) do
    ctx.root_contexts
    |> Enum.map(&display_under(tag, ctx, &1 ++ ctx.ancestor_classes))
    |> Enum.uniq()
    |> case do
      [display] -> display
      _ -> :ambiguous
    end
  end

  defp display_under(%HTMLNode{name: name} = tag, ctx, ancestors) do
    classes = static_classes(tag)

    cond do
      name in @inline_block_tags ->
        :inline_block

      Enum.any?(ctx.parent_classes, &(name in Map.get(@inline_block_children, &1, []))) ->
        :inline_block

      Enum.any?(ancestors, &(name in descendant_inline_blocks(&1))) ->
        :inline_block

      Enum.any?(classes, &(&1 in @inline_block_classes)) ->
        :inline_block

      Enum.any?(classes, &(&1 in @inline_classes)) ->
        :inline

      name == "li" and (ctx.in_inline_items or @inline_items_class in ancestors) ->
        :inline

      name == "li" and @any_context in ancestors ->
        :ambiguous

      name in @inline_tags ->
        :inline

      true ->
        :block
    end
  end

  defp descendant_inline_blocks(@any_context),
    do: @inline_block_descendants |> Map.values() |> Enum.concat()

  defp descendant_inline_blocks(class), do: Map.get(@inline_block_descendants, class, [])

  defp flex?(%HTMLNode{name: name, attributes: attrs} = tag, ctx) do
    classes = static_classes(tag)

    Enum.any?(classes, &(&1 in @flex_classes)) or
      List.keyfind(attrs, "id", 0) in Enum.map(@flex_ids, &{"id", &1}) or
      ("field" in classes and ctx.in_hform) or
      (name == "nav" and "page__pagination" in ctx.parent_classes)
  end

  # Kinds facing the children from inside the element. Whitespace at the
  # edge of an inline element collapses like whitespace right outside it.
  defp inner_edges(tag, ctx, before, after_) do
    if display(tag, ctx) in [:inline, :ambiguous] do
      {if(tag.spaces[:leading] == true, do: :safe, else: before),
       if(tag.spaces[:trailing] == true, do: :safe, else: after_)}
    else
      {:safe, :safe}
    end
  end

  defp static_classes(%HTMLNode{attributes: attrs}) do
    case List.keyfind(attrs, "class", 0) do
      {_, value} when is_binary(value) ->
        String.split(value)

      {_, {:eex, code}} ->
        code_classes(code)

      _ ->
        []
    end
  end

  defp code_classes(code) do
    ~r/"([^"]*)"/
    |> Regex.scan(code)
    |> Enum.flat_map(fn [_, s] -> String.split(Regex.replace(~r/#\{[^}]*\}/, s, " ")) end)
  end

  defp preserve?(%HTMLNode{name: name} = tag),
    do: name in @preserve_tags or Enum.any?(static_classes(tag), &(&1 in @preserve_classes))

  ## Formatter model
  #
  # The formatter sees tags, text, expressions and code blocks. It inserts a
  # line break between two siblings with nothing in between when one of them
  # is a code block and the other is not text, or when an expression is
  # followed by a block-level tag that is not itself followed by an
  # expression or text. It also breaks inside every code block body and
  # inside block-level tags.

  defp fmt_types(%HTMLNode{name: name}) do
    type = if name in @inline_tags, do: :tag_inline, else: :tag_block
    {type, type}
  end

  defp fmt_types(%EExNode{} = eex) do
    cond do
      comment?(eex) -> {:comment, :comment}
      opens_block?(eex) -> {:eex_block, :eex_block}
      eex.output -> {:expr, :expr}
      true -> {:assign, :assign}
    end
  end

  defp fmt_types(%VerbatimTextNode{content: content}) do
    items = Enum.reject(content, &(&1 == ""))
    {text_type(List.first(items)), text_type(List.last(items))}
  end

  defp fmt_types(_node), do: {:text, :text}

  defp text_type({:eex, _}), do: :expr
  defp text_type(_text), do: :text

  defp inserts_break?(prev, next, next_preserved) do
    cond do
      prev == :text or next == :text -> false
      prev == :eex_block or next == :eex_block -> true
      prev in [:expr, :assign, :comment] and next == :tag_block -> not next_preserved
      prev == :tag_block and next == :comment -> true
      true -> false
    end
  end

  ## Compilation

  # Compiles a list of sibling nodes. `left` and `right` are the kinds of
  # whatever renders immediately before and after the list.
  defp compile_children([], _ctx, _left, _right, _inner, _outer), do: []

  defp compile_children(nodes, ctx, left, right, inner, outer) do
    kinds = Enum.map(nodes, &kinds(&1, ctx))

    trails = Enum.scan(kinds, left, fn {_, trail, empty}, acc -> face(trail, empty, acc) end)

    leads =
      kinds
      |> Enum.reverse()
      |> Enum.scan(right, fn {lead, _, empty}, acc -> face(lead, empty, acc) end)
      |> Enum.reverse()

    # befores[i] is the kind facing node i from the left, afters[i] from the right
    befores = Enum.take([left | trails], length(nodes))
    afters = tl(leads) ++ [right]
    safe = Enum.zip_with(befores, leads, &break?(&1, &2, ctx))

    # Line breaks only go next to block-level nodes, comments and code lines,
    # so inline content stays on one line until the formatter wraps it. The
    # edges of an element only break around such children, and never inside
    # an inline tag: the formatter treats an inline tag with a line break at
    # its edge as block-level and breaks around it.
    types = Enum.map(nodes, &fmt_types/1)
    neighbors = Enum.zip([nil | Enum.map(types, &elem(&1, 1))], Enum.map(types, &elem(&1, 0)))
    line_children = Enum.any?(types, fn {lead, trail} -> line_neighbor?(lead, trail) end)
    edges = line_children and not ctx.inline_parent

    breaks =
      Enum.zip_with(safe, neighbors, fn
        safe, {nil, _next} -> safe and edges
        safe, {prev, next} -> safe and line_neighbor?(prev, next)
      end)

    check_siblings(nodes, types, breaks, safe, ctx)

    docs =
      [nodes, befores, afters, breaks]
      |> Enum.zip()
      |> Enum.map(fn {node, before, after_, break} ->
        gap = if break, do: ["\n", inner], else: []
        [gap, compile(node, ctx, before, after_, inner)]
      end)

    closing = if break?(List.last(trails), right, ctx) and edges, do: ["\n", outer], else: []

    [docs, closing]
  end

  @line_types [:tag_block, :eex_block, :comment, :assign]

  defp line_neighbor?(prev, next), do: prev in @line_types or next in @line_types

  defp check_siblings(nodes, types, breaks, safe, ctx) do
    # A tag directly followed by an expression or text is kept as is
    preserved =
      Enum.zip_with([types, tl(types) ++ [nil], tl(breaks) ++ [true]], fn
        [_, {next, _}, false] -> next in [:expr, :assign, :text]
        _ -> false
      end)

    [types, tl(types), tl(breaks), tl(safe), tl(preserved), nodes, tl(nodes)]
    |> Enum.zip()
    |> Enum.each(fn {{_, prev}, {next, _}, break, safe, next_preserved, prev_node, next_node} ->
      if not break and not safe and inserts_break?(prev, next, next_preserved),
        do: damage(ctx, {:sibling, describe(prev_node), describe(next_node)})
    end)
  end

  defp describe(%HTMLNode{name: name} = tag),
    do: "<#{name} #{Enum.join(static_classes(tag), ".")}>"

  defp describe(%EExNode{content: code}), do: inspect(String.slice(String.trim(code), 0, 50))
  defp describe(%VerbatimTextNode{content: c}), do: inspect(c |> inspect() |> String.slice(0, 40))
  defp describe(node), do: inspect(node, limit: 3)

  defp compile(%DoctypeNode{name: name}, _ctx, _before, _after, _indent), do: Doctype.for(name)

  defp compile(%VerbatimTextNode{content: content}, ctx, _before, _after, _indent) do
    content
    |> Enum.map(&compile_text(&1, ctx))
    |> IO.iodata_to_binary()
    |> interpolated_html_attributes()
  end

  defp compile(%HTMLNode{name: name} = tag, ctx, before, after_, indent) do
    preserve = ctx.preserve or preserve?(tag)

    marked =
      MapSet.member?(ctx.no_format_marks, uid(tag)) or
        List.keymember?(tag.attributes, "phx-no-format", 0)

    no_format_attr =
      not ctx.no_format and not List.keymember?(tag.attributes, "phx-no-format", 0) and
        ((preserve and not ctx.preserve and name not in @formatter_preserve_tags) or marked)

    attrs =
      if no_format_attr, do: tag.attributes ++ [{"phx-no-format", true}], else: tag.attributes

    tag_head = Enum.join([name | Enum.map(attrs, &render_attribute/1)])

    body =
      cond do
        tag.closed and name not in @void_elements ->
          raise "#{ctx.file}: explicitly closed <#{name}/> is not a void element"

        name in @void_elements ->
          ["<", tag_head, " />"]

        true ->
          classes = static_classes(tag)

          child_ctx = %{
            ctx
            | preserve: preserve,
              no_format: ctx.no_format or preserve or marked,
              enclosing: uid(tag),
              parent_classes: classes,
              ancestor_classes: ctx.ancestor_classes ++ classes,
              in_inline_items: ctx.in_inline_items or @inline_items_class in classes,
              in_hform: ctx.in_hform or "hform" in classes,
              inline_parent: name in @inline_tags,
              flex: flex?(tag, ctx)
          }

          {left, right} = inner_edges(tag, ctx, before, after_)
          check_tag_edges(tag, child_ctx, left, right)

          children =
            compile_children(tag.children, child_ctx, left, right, indent <> "  ", indent)

          ["<", tag_head, ">", children, "</", name, ">"]
      end

    [leading_space(tag.spaces), body, trailing_space(tag.spaces)]
  end

  defp compile(%EExNode{} = eex, ctx, before, after_, indent) do
    cond do
      eex.safe? ->
        raise "#{ctx.file}: == operator used to include safe content in template; mark as raw in view instead"

      comment?(eex) ->
        compile_comment(eex)

      not opens_block?(eex) ->
        record_render(eex, ctx, before, after_)
        [leading_space(eex.spaces), compile_code(eex), trailing_space(eex.spaces)]

      true ->
        [
          leading_space(eex.spaces),
          compile_block(eex, ctx, before, after_, indent),
          trailing_space(eex.spaces)
        ]
    end
  end

  defp compile(%InlineHTMLNode{}, ctx, _before, _after, _indent) do
    raise "#{ctx.file}: Inline HTML not supported"
  end

  defp compile(%HTMLCommentNode{content: content}, _ctx, _before, _after, _indent) do
    ["<!--", Enum.map(content, &raw/1), "-->"]
  end

  defp compile(other, ctx, _before, _after, _indent) do
    raise "#{ctx.file}: unexpected node #{inspect(other)}"
  end

  # The formatter breaks inside block-level tags, which shows when
  # assets/css lays the tag out inline
  defp check_tag_edges(%HTMLNode{name: name, children: [_ | _] = children}, ctx, left, right)
       when name not in @inline_tags do
    if not (break?(left, first_kind(children, ctx, right), ctx) and
              break?(last_kind(children, ctx, left), right, ctx)),
       do: damage(ctx, :tag_edge)
  end

  defp check_tag_edges(_tag, _ctx, _left, _right), do: :ok

  defp compile_code(%EExNode{content: code, output: true}), do: expression(code)
  defp compile_code(%EExNode{content: code}), do: ["<% ", String.trim(code), " %>"]

  # Curly interpolation, unless braces in the code would end it early
  defp expression(code) do
    code = String.trim(code)
    if balanced_braces?(code, 0), do: ["{", code, "}"], else: ["<%= ", code, " %>"]
  end

  defp balanced_braces?("{" <> rest, depth), do: balanced_braces?(rest, depth + 1)
  defp balanced_braces?("}" <> _rest, 0), do: false
  defp balanced_braces?("}" <> rest, depth), do: balanced_braces?(rest, depth - 1)
  defp balanced_braces?(<<_::utf8, rest::binary>>, depth), do: balanced_braces?(rest, depth)
  defp balanced_braces?(<<>>, depth), do: depth == 0

  defp compile_block(eex, ctx, before, after_, indent) do
    if not eex.output do
      raise "#{ctx.file}: non-output block #{inspect(eex.content)} discards its body"
    end

    inner = indent <> "  "
    code = String.trim(eex.content)

    {left, right} =
      case wrapper(code) do
        :control -> {before, after_}
        :form -> {:safe, :safe}
        :block -> {:safe, :safe}
        :loop -> loop_edges(eex, ctx, before, after_)
        :inline -> wrapper_edges(code, before, after_)
      end

    # Helpers other than control flow wrap the body in an element
    ctx =
      case wrapper(code) do
        :form ->
          %{
            ctx
            | flex: false,
              inline_parent: false,
              in_hform: ctx.in_hform or "hform" in class_option(code)
          }

        :block ->
          %{ctx | flex: false, inline_parent: false}

        :inline ->
          %{ctx | flex: false, inline_parent: true}

        _ ->
          ctx
      end

    clauses = clause_bodies(eex)

    marker_indents =
      Enum.map(clauses, fn {clause, _} -> if stab?(clause), do: inner, else: indent end)

    next_indents = tl(marker_indents) ++ [indent]

    docs =
      [clauses, next_indents, Stream.iterate(0, &(&1 + 1))]
      |> Enum.zip()
      |> Enum.map(fn {{clause, body}, next_indent, index} ->
        body_indent = if stab?(clause), do: inner <> "  ", else: inner

        # Whitespace before the first clause of case/cond is discarded
        marker =
          cond do
            is_nil(clause) -> []
            index == 0 and stab?(clause) -> ["\n", inner, "<% ", clause, " %>"]
            true -> ["<% ", clause, " %>"]
          end

        if not (is_nil(clause) and stab_block?(clauses)) do
          check_body_edges(eex, body, ctx, left, right)
        end

        [marker, compile_children(body, ctx, left, right, body_indent, next_indent)]
      end)

    closing = if opens_block?(eex), do: "<% end %>", else: []

    ["<%= ", code, " %>", docs, closing]
  end

  # The formatter breaks at both edges of every code block body
  defp check_body_edges(eex, body, ctx, left, right) do
    if not (break?(left, first_kind(body, ctx, right), ctx) and
              break?(last_kind(body, ctx, left), right, ctx)),
       do: damage(ctx, {:body, describe(eex)}, uid(eex))
  end

  defp stab?(clause), do: is_binary(clause) and String.ends_with?(clause, "->")

  # Whitespace at the edges of a loop body also faces the previous and next
  # iteration.
  defp loop_edges(eex, ctx, before, after_) do
    {first, last, _} = list_kinds(eex.children, ctx)

    left = if before == :safe and last == :safe, do: :safe, else: :unsafe
    right = if after_ == :safe and first == :safe, do: :safe, else: :unsafe

    {left, right}
  end

  # Helpers like `link` wrap their body in an inline element, whose edges
  # are safe when it is laid out as inline-block (buttons are by default)
  defp wrapper_edges(code, before, after_) do
    if Regex.match?(~r/^submit\b/, code) or
         code |> class_option() |> Enum.any?(&(&1 in @inline_block_classes)),
       do: {:safe, :safe},
       else: {before, after_}
  end

  defp class_option(code) do
    case Regex.run(~r/class: ("[^"]*")/, code) do
      [_, string] -> code_classes(string)
      nil -> []
    end
  end

  defp wrapper(code) do
    cond do
      Regex.match?(~r/^(if|unless|case|cond)\b/, code) -> :control
      Regex.match?(~r/^form_for\b/, code) -> :form
      # Both wrap the body in a div
      Regex.match?(~r/^(image_container\b|content_tag[ (]+:div\b)/, code) -> :block
      Regex.match?(~r/^(for|inputs_for|Enum\.\w+|\w+\.map_join|map_join)\b/, code) -> :loop
      true -> :inline
    end
  end

  defp opens_block?(%EExNode{content: code}), do: Regex.match?(~r/(fn.*->| do)\s*$/, code)

  # Splits the children of a block into `{clause, body}` pairs, where the
  # first clause is `nil` (the `do` body of `if`, or whitespace before the
  # first clause of `case`/`cond`). A clause body is made of the clause's
  # children followed by its siblings up to the next clause.
  defp clause_bodies(%EExNode{children: children}) do
    {first, rest} = Enum.split_while(children, &(not clause?(&1)))

    clauses =
      rest
      |> Enum.chunk_while(
        nil,
        fn node, acc ->
          cond do
            clause?(node) and acc -> {:cont, acc, {node, []}}
            clause?(node) -> {:cont, {node, []}}
            true -> {:cont, {elem(acc, 0), [node | elem(acc, 1)]}}
          end
        end,
        fn
          nil -> {:cont, nil}
          acc -> {:cont, acc, nil}
        end
      )
      |> Enum.map(fn {clause, siblings} ->
        {String.trim(clause.content), clause.children ++ Enum.reverse(siblings)}
      end)

    if first == [] and stab_block?(clauses), do: clauses, else: [{nil, first} | clauses]
  end

  defp clause?(%EExNode{output: false, content: content}) do
    content = String.trim(content)
    content == "else" or String.ends_with?(content, "->")
  end

  defp clause?(_node), do: false

  # Bodies of every branch a control block may render, including the empty
  # implicit `else` of `if` and `unless`
  defp branches(%EExNode{content: content} = eex) do
    clauses = clause_bodies(eex)

    bodies =
      for {clause, body} <- clauses, not is_nil(clause) or not stab_block?(clauses), do: body

    if Regex.match?(~r/^(if|unless)\b/, String.trim(content)) and
         not Enum.any?(clauses, fn {clause, _} -> clause == "else" end),
       do: [[] | bodies],
       else: bodies
  end

  defp stab_block?(clauses), do: Enum.any?(clauses, fn {clause, _} -> stab?(clause) end)

  defp comment?(%EExNode{content: content}),
    do: String.starts_with?(content, @comment_marker <> "(")

  defp comment_indent(%EExNode{content: content}) do
    [_, n] = Regex.run(~r/\((\d+),/, content)
    String.to_integer(n)
  end

  defp compile_comment(%EExNode{content: content}) do
    [_, b64] = Regex.run(~r/"([^"]*)"/, content)
    text = b64 |> Base.decode64!() |> String.trim()

    if String.contains?(text, "\n"),
      do: ["<%!--\n", text, "\n--%>"],
      else: ["<%!-- ", text, " --%>"]
  end

  defp compile_text(text, _ctx) when is_binary(text), do: escape_text(text)

  defp compile_text({:eex, code}, _ctx), do: expression(code)

  defp compile_text({:safe_eex, _code}, ctx),
    do: raise("#{ctx.file}: Safe EEx not supported")

  # Text may contain raw HTML, whose attributes HEEx can only interpolate
  # as a whole value
  defp interpolated_html_attributes(text) do
    Regex.replace(~r/(<[a-zA-Z][^<>]*\s[\w-]+=)"([^"]*\{[^"]*)"/U, text, fn _, head, value ->
      value = Regex.replace(~r/\{(.*)\}/U, value, "\#{\\1}")
      ~s(#{head}{"#{value}"})
    end)
  end

  # HEEx reads `{` as interpolation and `<` as the start of a tag
  defp escape_text(text) do
    text
    |> String.replace("{", "&lbrace;")
    |> String.replace("}", "&rbrace;")
    |> then(&Regex.replace(~r/<(?![a-zA-Z\/!])/, &1, "&lt;"))
  end

  defp render_attribute({:special, name, code}), do: " #{name}={#{code}}"
  defp render_attribute({_, []}), do: ""
  defp render_attribute({_, ""}), do: ""

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

  defp render_attribute_code(name, content, _) do
    ~s[ #{name}={#{content}}]
  end

  defp raw({:eex, value}), do: "\#{" <> value <> "}"
  defp raw(value), do: value

  defp leading_space(%{leading: true}), do: " "
  defp leading_space(_), do: ""

  defp trailing_space(%{trailing: true}), do: " "
  defp trailing_space(_), do: ""
end
