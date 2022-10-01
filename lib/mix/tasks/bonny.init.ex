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
  @rfc_1123_subdomain_check ~r/^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$/

  def run(_args) do
    input =
      [
        resources: @default_resources,
        app_name: Mix.Bonny.app_name(),
        app_dir_name: Mix.Bonny.app_dir_name()
      ]
      |> get_input()

    create_discovery_file()
    create_conn_file(input)
    create_config_file(input)
    import_bonny_config_in_main_config()
    add_dynamic_http_provder_to_test_helper()
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

      !valid_rfc_1123_subdomain?(input[:api_group]) ->
        Mix.Bonny.error(
          "Invalid value: #{inspect(input[:api_group])}. A lowercase RFC 1123 subdomain must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character"
        )

        input
        |> Keyword.delete(:api_group)
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
        |> Keyword.put(:define_resources?, false)
        |> get_input()

      true ->
        input
    end
  end

  defp create_discovery_file() do
    "init/discovery.json"
    |> Mix.Bonny.template()
    |> Mix.Bonny.copy("test/support/discovery.json")
  end

  defp create_config_file(input) do
    "init/config.exs"
    |> Mix.Bonny.template()
    |> Mix.Bonny.render_template("config/bonny.exs", input)
  end

  defp create_conn_file(input) do
    "init/k8s_conn.ex"
    |> Mix.Bonny.template()
    |> Mix.Bonny.render_template("lib/#{input[:app_dir_name]}/k8s_conn.ex", input)
  end

  defp import_bonny_config_in_main_config() do
    check = ~s(import_config "bonny.exs")

    append_conent = ~s(\n\n#{check})

    new_file_content = """
    import Config
    #{append_conent}
    """

    check = ~s(import_config "bonny.exs")
    Mix.Bonny.append_or_create_with("config/config.exs", append_conent, new_file_content, check)
  end

  defp add_dynamic_http_provder_to_test_helper() do
    check = "K8s.Client.DynamicHTTPProvider.start_link(nil)"
    content_to_prepend = "#{check}\n"

    new_file_content = """
    #{content_to_prepend}
    ExUnit.start()
    """

    Mix.Bonny.prepend_or_create_with(
      "config/config.exs",
      content_to_prepend,
      new_file_content,
      check
    )
  end

  defp valid_rfc_1123_subdomain?(string), do: String.match?(string, @rfc_1123_subdomain_check)
end
