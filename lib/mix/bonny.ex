defmodule Mix.Bonny do
  @moduledoc """
  Mix task helpers
  """

  @doc "Parse CLI input"
  @spec parse_args([binary()], Keyword.t(), Keyword.t()) ::
          {Keyword.t(), [binary()], [{binary(), nil | binary()}]}

  def parse_args(args, defaults, cli_opts \\ []) do
    {opts, parsed, invalid} = OptionParser.parse(args, cli_opts)
    merged_opts = Keyword.merge(defaults, opts)

    {merged_opts, parsed, invalid}
  end

  @doc """
  Capitalizes the string if it does not begin with a capital letter.
  """
  def ensure_module_name(string) do
    if string =~ ~r/[A-Z].+/, do: string, else: String.capitalize(string)
  end

  @doc """
  Render text to a file.

  Special handling for the path "-" will render to STDOUT
  """
  @spec render(binary, binary) :: term()
  def render(source, "-"), do: IO.puts(source)

  def render(source, target) do
    Mix.Generator.create_file(target, source)
  end

  @spec render_template(binary(), binary(), keyword()) :: term()
  def render_template(source, "-", bindings) do
    EEx.eval_file(source, bindings) |> IO.puts()
  end

  def render_template(source, target, bindings),
    do: Mix.Generator.copy_template(source, target, bindings)

  @spec copy(binary, binary) :: term()
  def copy(source, "-"), do: IO.puts(File.read!(source))
  def copy(source, target), do: Mix.Generator.copy_file(source, target)

  @doc """
  Appends `append_content` to `target`. If `target` does not exist, a new
  file with `new_file_content` is created.
  """
  @spec append_or_create_with(binary(), binary(), binary(), binary()) :: term()
  def append_or_create_with(target, content_to_append, new_file_content, check) do
    add_or_create_with(:append, target, content_to_append, new_file_content, check)
  end

  @doc """
  Prepends `append_content` to `target`. If `target` does not exist, a new
  file with `new_file_content` is created.
  """
  @spec prepend_or_create_with(binary(), binary(), binary(), binary()) :: term()
  def prepend_or_create_with(target, content_to_prepend, new_file_content, check) do
    add_or_create_with(:prepend, target, content_to_prepend, new_file_content, check)
  end

  @spec add_or_create_with(:append | :prepend, binary(), binary(), binary(), binary()) :: term()
  def add_or_create_with(mode, target, content_to_add, new_file_content, check) do
    cond do
      !File.exists?(target) ->
        Mix.Generator.create_file(target, new_file_content)
        :ok

      !(File.read!(target) =~ check) && mode == :append ->
        add_content(mode, target, content_to_add)

      true ->
        :ok
    end
  end

  defp add_content(:append, target, content_to_add) do
    Owl.IO.puts([
      Owl.Data.tag("* appending", :green),
      "#{inspect(content_to_add)} to #{target}"
    ])

    {:ok, file} = File.open(target, [:append])
    IO.binwrite(file, content_to_add)
    File.close(file)
    :ok
  end

  defp add_content(:prepend, target, content_to_add) do
    Owl.IO.puts([
      Owl.Data.tag("* prepending", :green),
      "#{inspect(content_to_add)} to #{target}"
    ])

    file_content = File.read!(target)
    File.write!(target, content_to_add <> file_content)
    :ok
  end

  @doc "Get the OTP app name"
  @spec app_name() :: binary
  def app_name() do
    otp_app()
    |> Atom.to_string()
    |> Macro.camelize()
  end

  @doc "Get the OTP app name with dashes"
  @spec hyphenated_app_name() :: binary
  def hyphenated_app_name() do
    otp_app()
    |> Atom.to_string()
    |> String.replace("_", "-")
  end

  @spec app_dir_name() :: binary
  def app_dir_name() do
    Macro.underscore(app_name())
  end

  @spec template(binary) :: binary
  def template(name) do
    template_dir = Application.app_dir(:bonny, ["priv", "templates", "bonny.gen"])
    Path.join(template_dir, name)
  end

  @spec no_umbrella! :: any
  def no_umbrella!() do
    if Mix.Project.umbrella?() do
      Mix.raise("mix bonny.gen.* can only be run inside an application directory")
    end
  end

  @spec otp_app :: atom
  defp otp_app() do
    Mix.Project.config() |> Keyword.fetch!(:app)
  end

  def error(message) do
    message |> Owl.Data.tag(:red) |> Owl.IO.puts()
  end
end
