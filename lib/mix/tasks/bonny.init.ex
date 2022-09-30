defmodule Mix.Tasks.Bonny.Init do
  @moduledoc """
  Initialized an operator wiht bonny

  * Initializes config
  """

  use Mix.Task

  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @default_resources %{
    limits: %{cpu: "200m", memory: "200Mi"},
    requests: %{cpu: "200m", memory: "200Mi"}
  }

  @switches [out: :string]
  @aliases [o: :out]

  def run(args) do
    {opts, _args, _} = Mix.Bonny.parse_args(args, [], switches: @switches, aliases: @aliases)

    input =
      [resources: @default_resources]
      |> get_input()

    generate_config(input, opts)
    add_config_to_main_config()
  end

  def get_input(input \\ []) do
    cond do
      is_nil(input[:api_group]) ->
        api_group =
          Owl.IO.input(
            label: "Please enter the API Group of your controller, e.g. your-operator.example.com"
          )

        input
        |> Keyword.put(:api_group, api_group)
        |> get_input()

      is_nil(input[:version]) ->
        version =
          Owl.IO.input(
            label:
              "Please enter the API Version of your controller in Elixir module form, e.g. V1 or V1Alpha1"
          )

        input
        |> Keyword.put(
          :version,
          "#{Mix.Bonny.app_name()}.API.#{Mix.Bonny.ensure_module_name(version)}"
        )
        |> get_input()

      is_nil(input[:namespace]) ->
        namespace =
          Owl.IO.input(
            label:
              ~s(Please enter the The namespace to watch for namespaced resources. Enter :all to watch all namespaces. Defaults to "default"),
            optional: true
          )

        namespace = if namespace == ":all", do: :all, else: namespace || "default"

        input
        |> Keyword.put(:namespace, namespace)
        |> get_input()

      is_nil(input[:operator_name]) ->
        default = Mix.Bonny.hyphenated_app_name()

        operator_name =
          Owl.IO.input(
            label:
              ~s(Please enter the name of your operator. It must only consist of only lowercase letters and hyphens. Defaults to "#{default}"),
            optional: true
          )

        input
        |> Keyword.put(:operator_name, operator_name || default)
        |> get_input()

      is_nil(input[:service_account_name]) ->
        default = Mix.Bonny.hyphenated_app_name()

        service_account_name =
          Owl.IO.input(
            label:
              ~s(Please enter the name of th service account. It must only consist of only lowercase letters and hyphens. Defaults to "#{default}"),
            optional: true
          )

        input
        |> Keyword.put(:service_account_name, service_account_name || default)
        |> get_input()

      is_nil(input[:define_resources?]) ->
        define_resources? =
          Owl.IO.confirm(
            message:
              ~s(Would you like to customize the resources? Defaults to #{inspect(@default_resources)}")
          )

        input
        |> Keyword.put(:define_resources?, define_resources?)
        |> get_input()

      input[:define_resources?] ->
        cpu_request = Owl.IO.input(label: "Please enter the value for the CPU request, e.g. 200m")

        mem_request =
          Owl.IO.input(label: "Please enter the value for the memory request, e.g. 200Mi")

        cpu_limit = Owl.IO.input(label: "Please enter the value for the CPU limit, e.g. 200m")
        mem_limit = Owl.IO.input(label: "Please enter the value for the memory limit, e.g. 200Mi")

        input
        |> Keyword.put(:resources, %{
          limits: %{cpu: cpu_limit, memory: mem_limit},
          requests: %{cpu: cpu_request, memory: mem_request}
        })
        |> get_input()

      true ->
        input
    end
  end

  defp generate_config(input, opts) do
    config_out = opts[:out] || "config/bonny.exs"

    "config.exs"
    |> Mix.Bonny.template()
    |> EEx.eval_file(input)
    |> Mix.Bonny.render(config_out)
  end

  defp add_config_to_main_config() do
    cond do
      !File.exists?("config/config.exs") ->
        Owl.IO.puts([Owl.Data.tag("* adding", :green), " config/bonny.exs to config/config.exs"])

        content = """
        import Config

        import_config "bonny.exs"
        """

        File.write!("config/config.exs", content)

      !(File.read!("config/config.exs") =~ ~s(import_config "bonny.exs")) ->
        Owl.IO.puts([Owl.Data.tag("* adding", :green), " config/bonny.exs to config/config.exs"])

        content = """

        import_config "bonny.exs"
        """

        {:ok, file} = File.open("config/config.exs", [:append])
        IO.binwrite(file, content)
        File.close(file)

      true ->
        :ok
    end
  end
end
