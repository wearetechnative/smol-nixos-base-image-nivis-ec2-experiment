# The EC2 pipeline for gate 2, as nivis resources.
#
# Shaped after nivis's own nix/example/ec2.nix, with three deliberate
# differences (experiments/000-nivis.md):
#
#   1. An aws_key_pair, and key_name on the instance, so the verification key
#      reaches the guest through instance metadata. Contract check 1 is only
#      real because of this.
#   2. Ingress on 22, not 80. The lab verifies over SSH, it does not serve.
#   3. No aws_s3_bucket and no aws_iam_role. The lab bucket and the vmimport
#      role are created once by infra/iam/bootstrap.sh, so SmolLabRole needs
#      no IAM write permission and no s3:CreateBucket.
{
  nivis,
  nixosConfigurations,
}:
ledger:
let
  inherit (nivis)
    mkResource
    mkProvider
    mkVars
    toIR
    drv
    ;

  vars = mkVars {
    variant = {
      type = "str";
      default = "candidate";
    };
    experiment = {
      type = "str";
    };
    region = {
      type = "str";
    };
    bucket = {
      type = "str";
    };
    instanceType = {
      type = "str";
      default = "t3.micro";
    };
    sshPublicKey = {
      type = "str";
    };
    system = {
      type = "str";
      default = "x86_64-linux";
    };
  } (ledger.vars or { });

  name = "smol-${vars.experiment}";

  image = nixosConfigurations."${vars.variant}-${vars.system}".config.system.build.images.amazon;

  keyPair = mkResource {
    provider = "aws";
    type = "aws_key_pair";
    name = "verify";
    config = {
      key_name = name;
      public_key = vars.sshPublicKey;
    };
  };

  # The image is a build output: nivis realises it before uploading, using the
  # derivation's passthru.filePath. No separate nix build, no store path
  # interpolation by hand.
  upload = mkResource {
    provider = "aws";
    type = "aws_s3_object";
    name = "image";
    config = {
      bucket = vars.bucket;
      key = "${name}.vhd";
      source = drv image;
    };
  };

  # disk_container and user_bucket are list-nested blocks in the AWS provider;
  # a bare attrset is rejected at apply.
  snapshot = mkResource {
    provider = "aws";
    type = "aws_ebs_snapshot_import";
    name = "image";
    config = {
      role_name = "vmimport";
      disk_container = [
        {
          format = "VHD";
          user_bucket = [
            {
              s3_bucket = vars.bucket;
              s3_key = upload.refAttr "key";
            }
          ];
        }
      ];
    };
  };

  ami = mkResource {
    provider = "aws";
    type = "aws_ami";
    name = "image";
    config = {
      name = name;
      virtualization_type = "hvm";
      root_device_name = "/dev/xvda";
      ena_support = true;
      sriov_net_support = "simple";
      ebs_block_device = [
        {
          device_name = "/dev/xvda";
          snapshot_id = snapshot.refAttr "id";
          delete_on_termination = true;
        }
      ];
    };
  };

  securityGroup = mkResource {
    provider = "aws";
    type = "aws_security_group";
    name = "verify";
    config = {
      name = name;
      description = "smol lab gate 2: SSH in, anything out";
      ingress = [
        {
          from_port = 22;
          to_port = 22;
          protocol = "tcp";
          cidr_blocks = [ "0.0.0.0/0" ];
          description = "ssh";
        }
      ];
      egress = [
        {
          from_port = 0;
          to_port = 0;
          protocol = "-1";
          cidr_blocks = [ "0.0.0.0/0" ];
          description = "all";
        }
      ];
    };
  };

  instance = mkResource {
    provider = "aws";
    type = "aws_instance";
    name = "target";
    config = {
      ami = ami.refAttr "id";
      instance_type = vars.instanceType;
      key_name = keyPair.refAttr "key_name";
      vpc_security_group_ids = [ (securityGroup.refAttr "id") ];
      tags = {
        Name = name;
      };
    };
  };
in
toIR {
  providers.aws = mkProvider {
    source = "registry.opentofu.org/hashicorp/aws";
    config = {
      region = vars.region;
      # A list-nested block in the AWS provider. These two tags are what the
      # IAM policy's create and delete conditions key on, so every taggable
      # resource must carry them.
      default_tags = [
        {
          tags = {
            Project = "smol-lab";
            Experiment = vars.experiment;
          };
        }
      ];
    };
  };

  resources = [
    keyPair
    upload
    snapshot
    ami
    securityGroup
    instance
  ];

  outputs = {
    public_ip = instance.refAttr "public_ip";
    instance_id = instance.refAttr "id";
    ami_id = ami.refAttr "id";
    snapshot_id = snapshot.refAttr "id";
  };

  inherit ledger;
}
