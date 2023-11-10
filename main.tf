locals {
  project_name     = coalesce(try(var.context["project"]["name"], null), "default")
  project_id       = coalesce(try(var.context["project"]["id"], null), "default_id")
  environment_name = coalesce(try(var.context["environment"]["name"], null), "test")
  environment_id   = coalesce(try(var.context["environment"]["id"], null), "test_id")
  resource_name    = coalesce(try(var.context["resource"]["name"], null), "example")
  resource_id      = coalesce(try(var.context["resource"]["id"], null), "example_id")

  domain_suffix = coalesce(var.infrastructure.domain_suffix, "cluster.local")
  namespace = coalesce(try(var.infrastructure.namespace, ""), join("-", [
    local.project_name, local.environment_name
  ]))
  annotations = {
    "walrus.seal.io/project-id"     = local.project_id
    "walrus.seal.io/environment-id" = local.environment_id
    "walrus.seal.io/resource-id"    = local.resource_id
  }
  labels = {
    "walrus.seal.io/project-name"     = local.project_name
    "walrus.seal.io/environment-name" = local.environment_name
    "walrus.seal.io/resource-name"    = local.resource_name
  }
}

#
# Random
#

# create a random password for blank password input.

resource "random_password" "password" {
  lower   = true
  length  = 8
  special = false
}

# create the name with a random suffix.

resource "random_string" "name_suffix" {
  length  = 10
  special = false
  upper   = false
}

locals {
  name     = join("-", [local.resource_name, random_string.name_suffix.result])
  password = coalesce(var.deployment.password, random_password.password.result)
}

#
# Deployment
#

locals {
  helm_release_values = [
    # basic configuration.

    {
      # global parameters: https://github.com/bitnami/charts/tree/main/bitnami/rabbitmq#global-parameters
      global = {
        image_registry = coalesce(var.infrastructure.image_registry, "registry-1.docker.io")
      }

      # common parameters: https://github.com/bitnami/charts/tree/main/bitnami/rabbitmq#common-parameters
      fullnameOverride  = local.name
      commonAnnotations = local.annotations
      commonLabels      = local.labels

      # rabbitmq image parameters: https://github.com/bitnami/charts/tree/main/bitnami/rabbitmq#rabbitmq-image-parameters
      image = {
        repository = "bitnami/rabbitmq"
        tag        = coalesce(var.deployment.version, "3.12.8")
      }

      auth = {
        username = coalesce(var.deployment.username, "user")
      }

      resources = {
        requests = try(var.deployment.resources.requests != null, false) ? {
          for k, v in var.deployment.resources.requests : k => "%{if k == "memory"}${v}Mi%{else}${v}%{endif}"
          if v != null && v > 0
        } : null
        limits = try(var.deployment.resources.limits != null, false) ? {
          for k, v in var.deployment.resources.limits : k => "%{if k == "memory"}${v}Mi%{else}${v}%{endif}"
          if v != null && v > 0
        } : null
      }

      persistence = {
        enabled      = try(var.deployment.storage != null, false)
        storageClass = try(var.deployment.storage.class, "")
        accessModes  = ["ReadWriteOnce"]
        size         = try(format("%dMi", var.deployment.storage.size), "20480Mi")
      }
    },
  ]
}

resource "helm_release" "rabbitmq" {
  chart       = "${path.module}/charts/rabbitmq-12.4.1.tgz"
  wait        = false
  max_history = 3
  namespace   = local.namespace
  name        = local.name

  values = [
    for c in local.helm_release_values : yamlencode(c)
    if c != null
  ]

  set_sensitive {
    name  = "auth.password"
    value = local.password
  }
}