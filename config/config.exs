# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
config :lfagent,
  sources: [
    %{
      path: "/private/var/log/system.log",
      source: "a6c5bca7-a8a7-4bda-a984-a873daaad8d0"
    },
    %{
      path: "/Users/chasegranberry/.cloudflared/cloudflared.log",
      source: "dc2804de-ef20-459d-93fd-8b6f938d2bb0"
    }
  ]

config :logger,
  level: :debug
