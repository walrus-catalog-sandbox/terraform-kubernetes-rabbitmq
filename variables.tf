#
# Contextual Fields
#

variable "context" {
  description = <<-EOF
Receive contextual information. When Walrus deploys, Walrus will inject specific contextual information into this field.

Examples:
```
context:
  project:
    name: string
    id: string
  environment:
    name: string
    id: string
  resource:
    name: string
    id: string
```
EOF
  type        = map(any)
  default     = {}
}

#
# Infrastructure Fields
#

variable "infrastructure" {
  description = <<-EOF
Specify the infrastructure information for deploying.

Examples:
```
infrastructure:
  namespace: string, optional
  image_registry: string, optional
  domain_suffix: string, optional
```
EOF
  type = object({
    namespace      = optional(string)
    image_registry = optional(string, "registry-1.docker.io")
    domain_suffix  = optional(string, "cluster.local")
  })
  default = {}
}

#
# Deployment Fields
#

variable "deployment" {
  description = <<-EOF
Specify the deployment action, including architecture and account.

Examples:
```
deployment:
  version: string, optional      # https://hub.docker.com/r/bitnami/rabbitmq/tags
  password: string, optional
  username: string, optional
  resources:
      requests:
        cpu: number
        memory: number             # in megabyte
      limits:
        cpu: number
        memory: number             # in megabyte
    storage:                       # convert to empty_dir volume if null or dynamic volume claim template
      class: string
      size: number, optional       # in megabyte
```
EOF
  type = object({
    version  = optional(string, "3.12.8")
    username = optional(string, "user")
    password = optional(string)
    resources = optional(object({
      requests = object({
        cpu    = optional(number, 0.25)
        memory = optional(number, 256)
      })
      limits = optional(object({
        cpu    = optional(number, 0)
        memory = optional(number, 0)
      }))
    }), { requests = { cpu = 0.25, memory = 256 } })
    storage = optional(object({
      class = optional(string)
      size  = optional(number, 20 * 1024)
    }), { size = 20 * 1024 })
  })
  default = {}
}