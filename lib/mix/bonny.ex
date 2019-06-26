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
  Render text to a file.

  Special handling for the path "-" will render to STDOUT
  """
  def render(source, "-"), do: IO.puts(source)

  def render(source, target) do
    Mix.Generator.create_file(target, source)
  end

  @doc "Get the OTP app name"
  def app_name() do
    otp_app()
    |> Atom.to_string()
    |> Macro.camelize()
  end

  def app_dir_name() do
    Macro.underscore(app_name())
  end

  def template(name) do
    template_dir = Application.app_dir(:bonny, ["priv", "templates", "bonny.gen"])
    Path.join(template_dir, name)
  end

  def no_umbrella! do
    if Mix.Project.umbrella?() do
      Mix.raise("mix bonny.gen.* can only be run inside an application directory")
    end
  end

  defp otp_app() do
    Mix.Project.config() |> Keyword.fetch!(:app)
  end
end
