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
end
