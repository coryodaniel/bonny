defmodule Mix.Tasks.Bonny.Gen do
  use Mix.Task
  alias Mix.Bonny.Operator

  @switches [cluster_scoped: :boolean]
  @default_opts [cluster_scoped: false]

  @shortdoc "Generate a new operator"
  def run(args) do
    if Mix.Project.umbrella? do
      Mix.raise "mix bonny.gen can only be run inside an application directory"
    end

    {mod_name, singular, plural, opts} = build(args)

    [lib_dir, test_dir] = dirs_to_generate(singular)
    files = files_to_generate(lib_dir, test_dir)

    Mix.Generator.create_directory(lib_dir)
    Mix.Generator.create_directory(test_dir)

    copy_files(mod_name, singular, plural, files)
  end

  defp app_name() do
    otp_app()
    |> Atom.to_string
    |> Macro.camelize
  end

  def otp_app() do
    Mix.Project.config |> Keyword.fetch!(:app)
  end

  defp copy_files(mod_name, singular, plural, files) do
    binding = [mod_name: mod_name, singular: singular, plural: plural, app_name: app_name()]
    template_dir = Application.app_dir(:bonny, ["priv", "templates", "bonny.gen"])

    Enum.each(files, fn({template, filename}) ->
      source = Path.join(template_dir, template)
      target = Path.join(".", filename)
      Mix.Generator.create_file(target, EEx.eval_file(source, binding))
    end)
  end

  defp dirs_to_generate(singular) do
    lib_dir = Path.join(["lib", "operators", singular])
    test_dir = Path.join(["test", "operators", singular])

    [lib_dir, test_dir]
  end

  defp files_to_generate(lib_dir, test_dir) do
    [
      {"controller.ex",       Path.join([lib_dir, "controller.ex"])},
      {"api.ex",              Path.join([lib_dir, "api.ex"])},
      {"controller_test.exs", Path.join([test_dir, "controller_test.exs"])}
    ]
  end

  defp build(args) do
    {opts, parsed, _} = parse_opts(args)
    [mod_name, plural | _] = validate_args!(parsed)

    singular = Macro.underscore(mod_name)

    {mod_name, singular, plural, opts}
  end

  defp parse_opts(args) do
    {opts, parsed, invalid} = OptionParser.parse(args, switches: @switches)
    merged_opts =
      @default_opts
      |> Keyword.merge(opts)

    {merged_opts, parsed, invalid}
  end

  defp validate_args!([mod_name, _plural | _] = args) do
    cond do
      not Operator.valid?(mod_name) ->
        raise_with_help "Expected the name, #{inspect mod_name}, to be a valid module name"
      true ->
        args
    end
  end

  defp validate_args!(_) do
    raise_with_help "Invalid arguments."
  end

 @doc false
 @spec raise_with_help(String.t) :: no_return()
 def raise_with_help(msg) do
   Mix.raise """
   #{msg}

   mix bonny.gen expects a module name followed by a the plural
   name of the generated resource.

   For example:
      mix bonny.gen Webhook webhooks
      mix bonny.gen Memcached memcached
   """
 end
end
