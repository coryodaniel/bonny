defmodule Bonny.AdmissionControl do
  require Logger

  import YamlElixir.Sigil

  def ensure_tls_config(conn) do
    with {:operator_name, operator_name} when is_binary(operator_name) <-
           {:operator_name, System.get_env("OPERATOR_NAME")},
         {:admission_config, [_ | _] = admission_configurations} <-
           {:admission_config, get_admission_config(conn, operator_name)},
         {:cert_bundle, {:ok, cert_bundle}} <-
           {:cert_bundle, get_or_create_cert_bundle(conn, operator_name)} do
      admission_configurations
      |> Enum.reject(fn config ->
        Enum.all?(
          List.wrap(config["webhooks"]),
          &(&1["clientConfig"]["caBundle"] == cert_bundle["ca"])
        )
      end)
      |> Enum.map(fn config ->
        put_in(
          config,
          ["webhooks", Access.all(), ["clientConfig"]["caBundle"]],
          cert_bundle["ca"]
        )
      end)
      |> Enum.each(&apply_admission_config(conn, &1))
    else
      {:operator_name, nil} ->
        Logger.error("Env variable OPERATOR_NAME is not defined.")
        :error

      {:admission_config, []} ->
        Logger.error("No admission configuration was found on the cluster.")
        :error

      {:cert_bundle, :error} ->
        # System.halt(1)
        :error
    end
  end

  defp get_or_create_cert_bundle(conn, operator_name) do
    with {:secret_namespace, secret_namespace} when is_binary(secret_namespace) <-
           {:secret_namespace, System.get_env("SECRET_NAMESPACE")},
         {:secret_name, secret_name} when is_binary(secret_name) <-
           {:secret_name, System.get_env("SECRET_NAME")},
         {:operator_namespace, operator_namespace} when is_binary(operator_namespace) <-
           {:operator_namespace, System.get_env("OPERATOR_NAMESPACE")},
         {:secret, _, _, _, _, {:ok, secret}} <-
           {:secret, operator_namespace, operator_name, secret_namespace, secret_name,
            get_secret(conn, secret_namespace, secret_name)},
         {:cert_bundle,
          %{"key" => _key, "cert" => _cert, "ca_key" => _ca_key, "ca" => _ca} = cert_bundle} <-
           {:cert_bundle, decode_secret(secret)} do
      {:ok, cert_bundle}
    else
      {:secret_namespace, nil} ->
        Logger.error("Env variable SECRET_NAMESPACE is not defined.")
        :error

      {:secret_name, nil} ->
        Logger.error("Env variable SECRET_NAME is not defined.")
        :error

      {:operator_namespace, nil} ->
        Logger.error("Env variable OPERATOR_NAMESPACE is not defined.")
        :error

      {:secret, operator_namespace, operator_name, secret_namespace, secret_name,
       {:error, %K8s.Client.APIError{reason: "NotFound"}}} ->
        Logger.info("Secret with certificate bundle was not found. Attempting to create it.")

        create_cert_bundle_and_secret(
          conn,
          operator_namespace,
          operator_name,
          secret_namespace,
          secret_name
        )

      {:secret, _, _, _, _, {:error, exception}}
      when is_exception(exception) ->
        Logger.error("Can't get secret with certificate bundle: #{Exception.message(exception)}")
        :error

      {:secret, _, _, _, _, {:error, _}} ->
        Logger.error("Can't get secret with certificate bundle.")
        :error

      {:cert_bundle, _} ->
        Logger.error("Certificate secret exists but has the wrong shape.")
        :error
    end
  end

  defp get_secret(conn, namespace, name) do
    K8s.Client.get("v1", "secret", name: name, namespace: namespace)
    |> K8s.Client.put_conn(conn)
    |> K8s.Client.run()
  end

  defp decode_secret(secret) do
    Map.new(secret["data"], fn {key, value} -> {key, Base.decode64!(value)} end)
  end

  defp create_cert_bundle_and_secret(
         conn,
         operator_namespace,
         operator_name,
         secret_namespace,
         secret_name
       ) do
    ca_key = X509.PrivateKey.new_ec(:secp256r1)

    ca =
      X509.Certificate.self_signed(
        ca_key,
        "/C=CH/ST=ZH/L=Zurich/O=Bonny/CN=Bonny Root CA",
        template: :root_ca
      )

    key = X509.PrivateKey.new_ec(:secp256r1)

    cert =
      key
      |> X509.PublicKey.derive()
      |> X509.Certificate.new(
        "/C=CH/ST=ZH/L=Zurich/O=Bonny/CN=Bonny Admission Control Cert",
        ca,
        ca_key,
        extensions: [
          subject_alt_name:
            X509.Certificate.Extension.subject_alt_name([
              "#{operator_name}-webhook-service",
              "#{operator_name}-webhook-service.#{operator_namespace}",
              "#{operator_name}-webhook-service.#{operator_namespace}.svc"
            ])
        ]
      )

    cert_bundle = %{
      "key" => X509.PrivateKey.to_pem(key),
      "cert" => X509.Certificate.to_pem(cert),
      "ca_key" => X509.PrivateKey.to_pem(ca_key),
      "ca" => X509.Certificate.to_pem(ca)
    }

    case create_secret(conn, secret_namespace, secret_name, cert_bundle) do
      {:ok, _} ->
        {:ok, cert_bundle}

      {:error, %K8s.Client.APIError{reason: "AlreadyExists"}} ->
        # Looks like another pod was faster. Let's just start over:
        get_or_create_cert_bundle(conn, operator_name)

      {:error, exception} when is_exception(exception) ->
        raise "Secret creation failed: #{Exception.message(exception)}"

      {:error, _} ->
        raise "Secret creation failed."
    end
  end

  defp create_secret(conn, namespace, name, data) do
    ~y"""
    apiVersion: v1
    kind: Secret
    metadata:
      name: #{name}
      namespace: #{namespace}
    """
    |> Map.put("stringData", data)
    |> K8s.Client.create()
    |> K8s.Client.put_conn(conn)
    |> K8s.Client.run()
  end

  defp get_admission_config(conn, operator_name) do
    validating_webhook_config =
      K8s.Client.get("admissionregistration.k8s.io/v1", "ValidatingWebhookConfiguration",
        name: "#{operator_name}"
      )
      |> K8s.Client.put_conn(conn)
      |> K8s.Client.run()

    mutating_webhook_config =
      K8s.Client.get("admissionregistration.k8s.io/v1", "MutatingWebhookConfiguration",
        name: "#{operator_name}"
      )
      |> K8s.Client.put_conn(conn)
      |> K8s.Client.run()

    [validating_webhook_config, mutating_webhook_config]
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(&elem(&1, 1))
  end

  defp apply_admission_config(conn, admission_config) do
    result =
      admission_config
      |> K8s.Client.apply()
      |> K8s.Client.put_conn(conn)
      |> K8s.Client.run()

    case result do
      {:ok, _} -> :ok
      {:error, _} -> raise "Could not patch admission config"
    end
  end
end
