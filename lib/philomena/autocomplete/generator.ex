defmodule Philomena.Autocomplete.Generator do
  @moduledoc """
  Compiled autocomplete binary for frontend usage.

  See assets/js/utils/local-autocompleter.ts for how this should be used.
  The file follows the following binary format:

      struct tag {
        uint8_t key_length;
        uint8_t key[];
        uint8_t association_length;
        uint32_t associations[];
      };

      struct tag_reference {
        uint32_t tag_location;
        union {
          int32_t raw;
          uint32_t num_uses;    ///< when positive
          uint32_t alias_index; ///< when negative, -alias_index - 1
        };
      };

      struct secondary_reference {
        uint32_t primary_location;
      };

      struct autocomplete_file {
        struct tag tags[];
        struct tag_reference primary_references[];
        struct secondary_reference secondary_references[];
        uint32_t format_version;
        uint32_t reference_start;
        uint32_t num_tags;
      };

  """

  alias Philomena.Tags.LocalAutocomplete

  @format_version 2
  @top_tags 50_000
  @max_associations 8

  @doc """
  Create the compiled autocomplete binary.

  See module documentation for the format. This is not expected to be larger
  than a few megabytes on average.
  """
  @spec generate() :: binary()
  def generate do
    {tags, associations} = tags_and_associations()

    # Tags are already sorted, so just add them to the file directly
    {tag_block, name_locations} =
      Enum.reduce(tags, {<<>>, %{}}, fn %{name: name}, {data, name_locations} ->
        pos = byte_size(data)
        assn = Map.get(associations, name, [])
        assn_bin = for id <- assn, into: <<>>, do: <<id::32-little>>

        {
          <<data::binary, byte_size(name)::8, name::binary, length(assn)::8, assn_bin::binary>>,
          Map.put(name_locations, name, pos)
        }
      end)

    # Link reference list; self-referential, so must be preprocessed to deal with aliases
    tag_block = int32_align(tag_block)
    reference_start = byte_size(tag_block)

    reference_indexes =
      tags
      |> Enum.with_index()
      |> Enum.map(fn {entry, index} -> {entry.name, index} end)
      |> Map.new()

    references =
      Enum.reduce(tags, <<>>, fn entry, references ->
        pos = Map.fetch!(name_locations, entry.name)

        if not is_nil(entry.alias_name) do
          target = Map.fetch!(reference_indexes, entry.alias_name)

          <<references::binary, pos::32-little, -(target + 1)::32-little>>
        else
          <<references::binary, pos::32-little, entry.images_count::32-little>>
        end
      end)

    # Reorder tags by name in their namespace to provide a secondary ordering
    secondary_references =
      tags
      |> Enum.map(&{name_in_namespace(&1.name), &1.name})
      |> Enum.sort()
      |> Enum.reduce(<<>>, fn {_k, v}, secondary_references ->
        target = Map.fetch!(reference_indexes, v)

        <<secondary_references::binary, target::32-little>>
      end)

    # Finally add the reference start and number of tags in the footer
    <<
      tag_block::binary,
      references::binary,
      secondary_references::binary,
      @format_version::32-little,
      reference_start::32-little,
      length(tags)::32-little
    >>
  end

  defp tags_and_associations do
    # Names longer than 255 bytes do not fit and will break parsing.
    # Sort is done in the application to avoid collation.
    tags =
      LocalAutocomplete.get_tags(@top_tags)
      |> Enum.filter(&(byte_size(&1.name) < 255))
      |> Enum.sort_by(& &1.name)

    associations =
      LocalAutocomplete.get_associations(tags, @max_associations)

    {tags, associations}
  end

  defp int32_align(bin) do
    # Right-pad a binary to be a multiple of 4 bytes.
    pad_bits = 8 * (4 - rem(byte_size(bin), 4))

    <<bin::binary, 0::size(pad_bits)>>
  end

  defp name_in_namespace(s) do
    # Remove the artist:, oc: etc. prefix from a tag name, if one is present.
    case String.split(s, ":", parts: 2, trim: true) do
      [_namespace, name] ->
        name

      [name] ->
        name

      _unknown ->
        s
    end
  end
end
