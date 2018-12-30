defmodule Bonny.ConfigTest do
  @moduledoc false
  use ExUnit.Case, async: false
  alias Bonny.Config

  describe "group/0" do
    test "defaults to hyphenated app name example.com" do
      original = Application.get_env(:bonny, :group)

      Application.delete_env(:bonny, :group)
      assert Config.group() == "bonny.example.com"

      Application.put_env(:bonny, :group, original)
    end

    test "can be set via config.exs" do
      original = Application.get_env(:bonny, :group)

      Application.put_env(:bonny, :group, "foo-bar.example.test")
      assert Config.group() == "foo-bar.example.test"

      Application.put_env(:bonny, :group, original)
    end
  end

  describe "service_account/0" do
    test "removes invalid characters" do
      original = Application.get_env(:bonny, :service_account_name)

      Application.put_env(:bonny, :service_account_name, "k3wl$")
      assert Config.service_account() == "k-wl-"

      Application.put_env(:bonny, :operaservice_account_nametor_name, original)
    end

    test "defaults to hyphenated app name" do
      original = Application.get_env(:bonny, :service_account_name)

      Application.delete_env(:bonny, :service_account_name)
      assert Config.service_account() == "bonny"

      Application.put_env(:bonny, :service_account_name, original)
    end

    test "can be set via config.exs" do
      original = Application.get_env(:bonny, :service_account_name)

      Application.put_env(:bonny, :service_account_name, "foo-bar")
      assert Config.service_account() == "foo-bar"

      Application.put_env(:bonny, :service_account_name, original)
    end
  end

  describe "name/0" do
    test "removes invalid characters" do
      original = Application.get_env(:bonny, :operator_name)

      Application.put_env(:bonny, :operator_name, "k3wl$")
      assert Config.name() == "k-wl-"

      Application.put_env(:bonny, :operator_name, original)
    end

    test "defaults to hyphenated app name" do
      original = Application.get_env(:bonny, :operator_name)

      Application.delete_env(:bonny, :operator_name)
      assert Config.name() == "bonny"

      Application.put_env(:bonny, :operator_name, original)
    end

    test "can be set via config.exs" do
      original = Application.get_env(:bonny, :operator_name)

      Application.put_env(:bonny, :operator_name, "foo-bar")
      assert Config.name() == "foo-bar"

      Application.put_env(:bonny, :operator_name, original)
    end
  end

  describe "namespace/0" do
    test "returns 'default' when not set" do
      assert Config.namespace() == "default"
    end

    test "can be set by env variable" do
      System.put_env("BONNY_POD_NAMESPACE", "prod")
      assert Config.namespace() == "prod"
      System.delete_env("BONNY_POD_NAMESPACE")
    end
  end

  describe "controllers/0" do
    test "must be set via config.exs" do
      original = Application.get_env(:bonny, :controllers)

      Application.put_env(:bonny, :controllers, [Test, Foo])
      assert Config.controllers() == [Test, Foo]

      Application.put_env(:bonny, :controllers, original)
    end
  end

  describe "labels/0" do
    test "can be set via config.exs" do
      original = Application.get_env(:bonny, :labels)

      Application.put_env(:bonny, :labels, %{"foo" => "bar"})
      assert Config.labels() == %{"foo" => "bar"}

      Application.put_env(:bonny, :labels, original)
    end
  end

  # describe "kubeconfig/0" do
  #   test "can be set via environment variable"
  #   test "can be set via config.exs"
  #   test "defaults to a service account"
  # end
end
