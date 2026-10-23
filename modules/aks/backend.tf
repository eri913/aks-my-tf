terraform {
  cloud {
    hostname     = "app.terraform.io" # replace with your TFE hostname if self-hosted
    organization = "your-org"         # replace with your TFE organization name

    workspaces {
      name = "cuberai-300-cluster-prod" # use cuberai-300-cluster-dev for dev
    }
  }
}
