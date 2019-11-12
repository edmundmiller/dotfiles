{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    awscli
    # ec2_api_tools
    google-cloud-sdk
    terraform_0_12
    terraform-providers.aws
  ];
}
