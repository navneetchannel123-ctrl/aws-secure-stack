provider "aws" {
  region = "us-east-1"
}

data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

module "security_module" {
  source = "./modules/web_stack"
  my_ip  = chomp(data.http.my_ip.response_body)
}