terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 1.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.32.0"
    }
  }
}

provider "coder" {}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}
data "coder_parameter" "cpu" {
  type         = "number"
  name         = "cpu"
  display_name = "CPU"
  description  = "CPU limit (cores)."
  default      = "2"
  icon         = "/emojis/1f5a5.png"
  mutable      = true
  validation {
    min = 1
    max = 99999
  }
  order = 1
}

data "coder_parameter" "memory" {
  type         = "number"
  name         = "memory"
  display_name = "Memory"
  description  = "Memory limit (GiB)."
  default      = "2"
  icon         = "/icon/memory.svg"
  mutable      = true
  validation {
    min = 1
    max = 99999
  }
  order = 2
}

data "coder_parameter" "workspaces_volume_size" {
  name         = "workspaces_volume_size"
  display_name = "Workspaces volume size"
  description  = "Size of the `/workspaces` volume (GiB)."
  default      = "10"
  type         = "number"
  icon         = "/emojis/1f4be.png"
  mutable      = false
  validation {
    min = 1
    max = 99999
  }
  order = 3
}

data "coder_parameter" "repo" {
  description  = "Select a repository to automatically clone and start working with a devcontainer."
  display_name = "Repository (auto)"
  mutable      = true
  name         = "repo"
  order        = 4
  type         = "string"
}

# data "coder_parameter" "github" {
#   display_name = "GITHUB Token"
#   name         = "GITHUB Token"
#   order        = 8
# }

data "coder_external_auth" "gitlab" {
    id = "swf-gitlab"
}

# data "coder_parameter" "devcontainer_builder" {
#   display_name = "Devcontainer Builder"
#   mutable      = true
#   name         = "devcontainer_builder"
#   default      = "154453013990.dkr.ecr.eu-central-1.amazonaws.com/coder/envbuilder:latest"
#   order        = 6
# }
# data "coder_parameter" "fallback_image" {
#   default      = "codercom/enterprise-base:ubuntu"
#   description  = "This image runs if the devcontainer fails to build."
#   display_name = "Fallback Image"
#   mutable      = true
#   name         = "fallback_image"
#   order        = 7
# }

locals {
  deployment_name            = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
  devcontainer_builder_image = "154453013990.dkr.ecr.eu-central-1.amazonaws.com/coder/envbuilder:latest"
  git_author_name            = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
  git_author_email           = data.coder_workspace_owner.me.email
  repo_url                   = data.coder_parameter.repo.value
}

variable "namespace" {
  type        = string
  default     = "coder"
  description = "The Kubernetes namespace to create workspaces in (must exist prior to creating workspaces). If the Coder host is itself running as a Pod on the same Kubernetes cluster as you are deploying workspaces to, set this to the same namespace."
}

provider "kubernetes" {
  # Authenticate via ~/.kube/config or a Coder-specific ServiceAccount, depending on admin preferences
  config_path = var.use_kubeconfig == true ? "/mnt/secrets/kube/config" : null
  # config_context = "arn:aws:eks:eu-central-1:154453013990:cluster/eks-dev-container-prod-cluster"
}

variable "use_kubeconfig" {
  type        = bool
  description = <<-EOF
  Use host kubeconfig? (true/false)

  Set this to false if the Coder host is itself running as a Pod on the same
  Kubernetes cluster as you are deploying workspaces to.

  Set this to true if the Coder host is running outside the Kubernetes cluster
  for workspaces.  A valid "~/.kube/config" must be present on the Coder host.
  EOF
  default     = true
}


##Coder agent resource##
resource "coder_agent" "main" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    set -e

    # Install the latest code-server.
    # Append "--version x.x.x" to install a specific version of code-server.
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server

    # # Start code-server in the background.
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &

    CODE_CLI=/tmp/code-server/bin/code-server
    
    DEVCONTAINER_JSON=".devcontainer/devcontainer.json"
    if [[ -f "$DEVCONTAINER_JSON" ]]; then
        EXTENSIONS=$(sed '/^ *\/\//d' "$DEVCONTAINER_JSON" | jq -r '.customizations.vscode.extensions[]?')
        if [[ -n "$EXTENSIONS" ]]; then
            # Loop over each extension and install it
            for EXTENSION in $EXTENSIONS; do
                $CODE_CLI --install-extension $EXTENSION
            done
        fi
    fi
    

  # #### Installing Devcontainer Microsoft extension into workspace ####

  # sudo curl -fsSL -o "/tmp/ms-vscode-remote.remote-containers.vsix" "https://ms-vscode.gallery.vsassets.io/_apis/public/gallery/publisher/ms-vscode-remote/extension/remote-containers/latest/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage" 

  # /tmp/code-server/bin/code-server --install-extension /workspaces/cdw-helm-charts/.devcontainer/ms-vscode.remote-explorer-0.5.2024111900.vsix

  # /tmp/code-server/bin/code-server --install-extension /workspaces/cdw-helm-charts/.devcontainer/ms-vscode-remote.remote-containers-0.393.0.vsix
 


   ## Install Docker ## 
  
  # Add Docker's official GPG key:
  sudo apt-get update
  sudo apt-get install ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install docker-ce=5:26.0.0-1~ubuntu.24.04~noble docker-ce-cli=5:26.0.0-1~ubuntu.24.04~noble containerd.io docker-buildx-plugin docker-compose-plugin -y
  sudo sed -i '62,70 s/^/#/' /etc/init.d/docker


    ## Verify Docker installation ##
    docker --version

    ## Start Docker engine
    sudo service docker start 


    
  EOT
  dir            = "/workspaces"

  # These environment variables allow you to make Git commits right away after creating a
  # workspace. Note that they take precedence over configuration defined in ~/.gitconfig!
  # You can remove this block if you'd prefer to configure Git manually or using
  # dotfiles. (see docs/dotfiles.md)
  env = {
    GIT_AUTHOR_NAME     = local.git_author_name
    GIT_AUTHOR_EMAIL    = local.git_author_email
    GIT_COMMITTER_NAME  = local.git_author_name
    GIT_COMMITTER_EMAIL = local.git_author_email
  }

  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display any information.
  # For basic resources, you can use the `coder stat` command.
  # If you need more control, you can write your own script.
  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $HOME"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    # get load avg scaled by number of cores
    script   = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval = 60
    timeout  = 1
  }

  metadata {
    display_name = "Swap Usage (Host)"
    key          = "7_swap_host"
    script       = <<EOT
      free -b | awk '/^Swap/ { printf("%.1f/%.1f", $3/1024.0/1024.0/1024.0, $2/1024.0/1024.0/1024.0) }'
    EOT
    interval     = 10
    timeout      = 1
  }
}

##Coder app resource##
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337/?folder=/workspaces"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "authenticated"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}
resource "kubernetes_persistent_volume" "devcontainer_pv" {
  metadata {
    name = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-devcontainerpv"
  }
  spec {
    capacity = {
      storage = "${data.coder_parameter.workspaces_volume_size.value}Gi"
    }
    access_modes = ["ReadWriteMany"]
    storage_class_name = "standard"
    persistent_volume_source {
      host_path {
        path = "/home/coder"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "devcontainer_pvc" {
  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-devcontainerpvc"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"     = "coder-pvc"
      "app.kubernetes.io/instance" = "coder-pvc-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
      "app.kubernetes.io/part-of"  = "coder"
      //Coder-specific labels.
      "com.coder.resource"       = "true"
      "com.coder.workspace.id"   = data.coder_workspace.me.id
      "com.coder.workspace.name" = data.coder_workspace.me.name
      "com.coder.user.id"        = data.coder_workspace_owner.me.id
      "com.coder.user.username"  = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteMany"]
    storage_class_name = "standard"
    resources {
      requests = {
        storage = "${data.coder_parameter.workspaces_volume_size.value}Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "main" {
  count = data.coder_workspace.me.start_count
  depends_on = [
    kubernetes_persistent_volume_claim.devcontainer_pvc
  ]
  wait_for_rollout = false
  metadata {
    name      = local.deployment_name
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = local.deployment_name
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
      "io.kubernetes.cri-o.userns-mode" = "auto:size=65536"
    }
  }

  spec {
    replicas = 1
    
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "coder-workspace"
      }
    }
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "coder-workspace"
        }
        annotations = {
          "io.kubernetes.cri-o.userns-mode" = "auto:size=65536"
    }
      }
      spec {
        runtime_class_name = "sysbox-runc"
        security_context {}
        restart_policy = "Always"
        service_account_name = "coder"
        dns_policy = "ClusterFirst"
        
        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.devcontainer_pvc.metadata.0.name
            read_only  = false
          }
        }
        container {
          name              = data.coder_workspace.me.name
          image             = "154453013990.dkr.ecr.eu-central-1.amazonaws.com/coder/envbuilder:latest"
          image_pull_policy = "Always"
          security_context {}
          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }
          env {
            name  = "CODER_AGENT_URL"
            value = data.coder_workspace.me.access_url
          }
          env {
            name  = "ENVBUILDER_GIT_URL"
            value = local.repo_url
          }
          env {
            name  = "ENVBUILDER_INIT_SCRIPT"
            value = coder_agent.main.init_script
          }
          env {
            name  = "ENVBUILDER_FALLBACK_IMAGE"
            value = "codercom/enterprise-base:ubuntu"
          }
          env {
            name  = "ENVBUILDER_GIT_USERNAME"
            value = local.git_author_name
          }
          env {
            name  = "ENVBUILDER_GIT_PASSWORD"
            value = data.coder_external_auth.gitlab.access_token
          }

          resources {
            requests = {
              "cpu"    = "2"
              "memory" = "2Gi"
            }
            limits = {
              "cpu"    = "${data.coder_parameter.cpu.value}"
              "memory" = "${data.coder_parameter.memory.value}Gi"
            }
          }
          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
            read_only  = false
          }
        }

        affinity {
          // This affinity attempts to spread out all workspace pods evenly across
          // nodes.
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 1
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["coder-workspace"]
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
