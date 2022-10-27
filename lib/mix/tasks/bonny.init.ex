defmodule Mix.Tasks.Bonny.Init do
  @moduledoc """
  Initialized an operator wiht bonny.

  * Initializes application configuration
  * Generates helper files for tests
  """

  use Mix.Task
  @shortdoc "Initialized an operator wiht bonny."

  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @default_resources %{
    limits: %{cpu: "200m", memory: "200Mi"},
    requests: %{cpu: "200m", memory: "200Mi"}
  }
  @rfc_1123_subdomain_check ~r/^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$/
  @dns_1035_label_check ~r/^[a-z]([-a-z0-9]*[a-z0-9])?$/
  @dns_1035_label_check_with_uppercase ~r/^[a-zA-Z]([-A-Za-z0-9]*[A-Za-z0-9])?$/
  def run(_args) do
    input =
      [
        resources: @default_resources,
        app_name: Mix.Bonny.app_name(),
        app_dir_name: Mix.Bonny.app_dir_name()
      ]
      |> get_input()

    input = create_controllers(input)
    create_version_files(input)
    create_operator_file(input)
    create_application_file(input)
    create_discovery_file(input)
    create_conn_file(input)
    create_config_file(input)
    import_bonny_config_in_main_config()
    add_dynamic_http_provder_to_test_helper()
    create_manifest_customizer(input)

    Owl.IO.puts([
      Owl.Data.tag(
        "Don't forget to configure the generated application module #{input[:app_name]}.Application to mix.exs",
        :yellow
      )
    ])
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
              ~s(Please enter the name of the service account when run in kubernetes. It must only consist of only lowercase letters and hyphens. Defaults to "#{default}"),
            optional: true
          )

        input
        |> Keyword.put(:service_account_name, service_account_name || default)
        |> get_input()

      is_nil(input[:define_resources?]) ->
        define_resources? =
          Owl.IO.confirm(
            message:
              ~s(Would you like to customize the resources of your kubernets deployment? Defaults to #{inspect(@default_resources)}")
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

      is_nil(input[:crd_done]) ->
        proposition = if input[:crds], do: "another", else: "a"

        if Owl.IO.confirm(
             message: "Would you like to define #{proposition} custom resource?",
             default: is_nil(input[:crds])
           ) do
          crd = get_crd_input()

          input
          |> Keyword.update(:crds, [crd], &[crd | &1])
          |> get_input()
        else
          input
          |> Keyword.put(:crds, List.wrap(input[:crds]))
          |> Keyword.put(:crd_done, true)
          |> get_input()
        end

      length(input[:crds]) > 0 && is_nil(input[:create_controllers]) ->
        create_controllers =
          Owl.IO.confirm(
            message: "Would you like to create controllers for your custom resources?",
            default: true
          )

        input
        |> Keyword.put(:create_controllers, create_controllers)
        |> get_input()

      true ->
        input
    end
  end

  defp get_crd_input(input \\ []) do
    cond do
      is_nil(input[:name]) ->
        crd_name = Owl.IO.input(label: "What's the name (kind) of the Custom Resource?")

        input
        |> Keyword.put(:name, crd_name)
        |> get_crd_input()

      !valid_dns_1035_label_with_uppdercase?(input[:name]) ->
        Mix.Bonny.error(
          "The CRD name you defined (#{input[:name]}) is not a valid kubernetes kind!"
        )

        input
        |> Keyword.delete(:name)
        |> get_crd_input()

      is_nil(input[:version]) ->
        version =
          Owl.IO.input(
            label:
              "Please enter the API Version of your custom resource in Elixir module form, e.g. V1 or V1Alpha1"
          )

        next_input =
          if valid_dns_1035_label?(String.downcase(version)) do
            input
            |> Keyword.put(
              :version,
              Mix.Bonny.ensure_module_name(version)
            )
          else
            Mix.Bonny.error(
              "Invalid value: #{inspect(input[:version])}. A DNS-1035 label must consist of lower case alphanumeric characters or '-', start with an alphabetic character, and end with an alphanumeric character"
            )

            input
          end

        get_crd_input(next_input)

      is_nil(input[:scope]) ->
        scope =
          Owl.IO.select(
            [:Namespaced, :Cluster],
            label: "What is the scope of your resource?",
            render_as: &Atom.to_string/1
          )

        input
        |> Keyword.put(:scope, scope)
        |> get_crd_input()

      true ->
        input
    end
  end

  defp create_controllers(input) do
    controllers =
      for crd <- input[:crds] do
        controller_name = crd[:name] <> "Controller"
        controller = Mix.Task.run("bonny.gen.controller", [controller_name])
        Mix.Task.reenable("bonny.gen.controller")
        Keyword.merge(controller, crd)
      end

    Keyword.put(input, :controllers, controllers)
  end

  defp create_version_files(input) do
    for crd <- input[:crds] do
      binding = Keyword.merge(crd, Keyword.take(input, [:app_name]))
      version_out = crd_version_path(crd[:version], Macro.underscore(crd[:name]))

      "version.ex"
      |> Mix.Bonny.template()
      |> Mix.Bonny.render_template(
        version_out,
        binding
      )
    end
  end

  defp create_operator_file(input) do
    input =
      input
      |> update_in([:crds, Access.all()], fn crd ->
        Bonny.API.CRD.new!(
          names: Bonny.API.CRD.kind_to_names(crd[:name]),
          scope: crd[:scope],
          group: input[:api_group],
          versions: [
            Module.concat([String.to_atom(input[:app_name]), API, crd[:version], crd[:name]])
          ]
        )
      end)
      |> update_in([:controllers, Access.all()], fn controller ->
        api_version = "#{input[:api_group]}/#{String.downcase(controller[:version])}"

        controller_module =
          Module.concat([input[:app_name], Controller, controller[:controller_name]])

        if controller[:scope] == :Namespaced do
          quote do
            %{
              query:
                K8s.Client.list(unquote(api_version), unquote(controller[:name]),
                  namespace: watching_namespace
                ),
              controller: unquote(controller_module)
            }
          end
        else
          quote do
            %{
              query: K8s.Client.list(unquote(api_version), unquote(controller[:name])),
              controller: unquote(controller_module)
            }
          end
        end
      end)

    output_file = "lib/#{input[:app_dir_name]}/operator.ex"

    "init/operator.ex"
    |> Mix.Bonny.template()
    |> Mix.Bonny.render_template(
      output_file,
      input
    )

    Mix.Task.run("format", [output_file])
  end

  defp create_application_file(input) do
    "init/application.ex"
    |> Mix.Bonny.template()
    |> Mix.Bonny.render_template(
      "lib/#{input[:app_dir_name]}/application.ex",
      input
    )
  end

  defp create_discovery_file(input) do
    grouped_crds =
      Enum.group_by(
        input[:crds],
        & &1[:version],
        fn crd ->
          names = Bonny.API.CRD.kind_to_names(crd[:name])

          %{
            kind: names.kind,
            name: names.plural,
            namespaced: crd[:scope] == :Namespaced,
            verbs: ["*"]
          }
        end
      )

    "init/discovery.json"
    |> Mix.Bonny.template()
    |> Mix.Bonny.render_template("test/support/discovery.json",
      grouped_crds: grouped_crds,
      api_group: input[:api_group]
    )
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

  defp create_manifest_customizer(input) do
    "init/customizer.ex"
    |> Mix.Bonny.template()
    |> Mix.Bonny.render_template("lib/mix/tasks/bonny.gen.manifest/customizer.ex", input)

    "init/customizer_test.exs"
    |> Mix.Bonny.template()
    |> Mix.Bonny.render_template("test/mix/tasks/bonny.gen.manifest/customizer_test.exs", input)
  end

  defp import_bonny_config_in_main_config() do
    check = ~s(import_config "bonny.exs")

    append_conent = ~s(\n\n#{check})

    new_file_content = """
    import Config
    #{append_conent}
    """

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
      "test/test_helper.exs",
      content_to_prepend,
      new_file_content,
      check
    )
  end

  defp crd_version_path(version, crd) do
    Path.join(["lib", Mix.Bonny.app_dir_name(), String.downcase(version), "#{crd}.ex"])
  end

  defp valid_rfc_1123_subdomain?(string), do: String.match?(string, @rfc_1123_subdomain_check)
  defp valid_dns_1035_label?(string), do: String.match?(string, @dns_1035_label_check)

  defp valid_dns_1035_label_with_uppdercase?(string),
    do: String.match?(string, @dns_1035_label_check_with_uppercase)
end
