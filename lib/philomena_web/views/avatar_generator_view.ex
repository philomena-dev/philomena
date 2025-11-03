defmodule PhilomenaWeb.AvatarGeneratorView do
  use PhilomenaWeb, :view
  import Bitwise

  alias Philomena.Avatars

  # todo: debranding

  def generated_avatar(displayed_name) do
    config = config()

    # Generate 8 pseudorandom numbers
    seed = :erlang.crc32(displayed_name)

    {rand, _acc} =
      Enum.map_reduce(1..8, seed, fn _elem, acc ->
        value = xorshift32(acc)
        {value, value}
      end)

    # Set kind (race, species, etc)
    {kind, rand} = at(kinds(config), rand)

    # Set the ranges for the colors we are going to make
    color_range = 128
    color_brightness = 72

    {body_r, body_g, body_b, rand} = rgb(0..color_range, color_brightness, rand)
    {hair_r, hair_g, hair_b, rand} = rgb(0..color_range, color_brightness, rand)
    {style_hr, _rand} = at(all_kinds(hair_shapes(config), kind), rand)

    # Creates bounded hex color strings
    color_primary = format("~2.16.0B~2.16.0B~2.16.0B", [body_r, body_g, body_b])
    color_secondary = format("~2.16.0B~2.16.0B~2.16.0B", [hair_r, hair_g, hair_b])

    # Make a character
    avatar_svg(config, color_primary, color_secondary, kind, style_hr)
  end

  # Build the final SVG for the character.
  #
  # Inputs to raw/1 are not user-generated.
  # sobelow_skip ["XSS.Raw"]
  defp avatar_svg(config, color_primary, color_secondary, kind, style_hr) do
    [
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"125\" height=\"125\" viewBox=\"0 0 125 125\" class=\"avatar-svg\">",
      background(config),
      for_kind(tail_shapes(config), kind)["shape"]
      |> String.replace("SECONDARY_COLOR", color_secondary),
      for_kind(body_shapes(config), kind)["shape"]
      |> String.replace("PRIMARY_COLOR", color_primary),
      style_hr["shape"] |> String.replace("SECONDARY_COLOR", color_secondary),
      all_kinds(extra_shapes(config), kind)
      |> Enum.map(&String.replace(&1["shape"], "PRIMARY_COLOR", color_primary)),
      "</svg>"
    ]
    |> List.flatten()
    |> Enum.map(&raw/1)
  end

  # https://en.wikipedia.org/wiki/Xorshift
  # 32-bit xorshift deterministic PRNG
  defp xorshift32(state) do
    state = state &&& 0xFFFF_FFFF
    state = bxor(state, state <<< 13)
    state = bxor(state, state >>> 17)

    bxor(state, state <<< 5)
  end

  # Generate pseudorandom, clamped RGB values with a specified
  # brightness and random source
  defp rgb(range, brightness, rand) do
    {r, rand} = at(range, rand)
    {g, rand} = at(range, rand)
    {b, rand} = at(range, rand)

    {r + brightness, g + brightness, b + brightness, rand}
  end

  # Pick an element from an enumerable at the specified position,
  # wrapping around as appropriate.
  defp at(list, [position | rest]) do
    length = Enum.count(list)
    position = rem(position, length)

    {Enum.at(list, position), rest}
  end

  defp for_kind(styles, kind), do: hd(all_kinds(styles, kind))

  defp all_kinds(styles, kind),
    do: Enum.filter(styles, &Enum.member?(&1["kinds"], kind))

  defp format(format_string, args), do: to_string(:io_lib.format(format_string, args))

  defp kinds(%{"kinds" => kinds}), do: kinds
  defp header(%{"header" => header}), do: header
  defp background(%{"background" => background}), do: background
  defp tail_shapes(%{"tail_shapes" => tail_shapes}), do: tail_shapes
  defp body_shapes(%{"body_shapes" => body_shapes}), do: body_shapes
  defp hair_shapes(%{"hair_shapes" => hair_shapes}), do: hair_shapes
  defp extra_shapes(%{"extra_shapes" => extra_shapes}), do: extra_shapes
  defp footer(%{"footer" => footer}), do: footer

  def config() do
    env_cache(:avatar_config, fn ->
      %{
        "kinds" => Avatars.get_kinds(),
        "parts" => Avatars.get_parts(),
        "shapes" => Avatars.get_shapes(),
        "shape_kinds" => Avatars.get_shape_kinds()
      }
    end)
  end
end
